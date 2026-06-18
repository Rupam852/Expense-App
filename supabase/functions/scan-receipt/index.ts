import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"
import { corsHeaders } from "../_shared/cors.ts"

async function getDynamicModels(userApiKey: string) {
  const defaultModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash-lite',
    'gemini-pro-latest'
  ]
  try {
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${userApiKey}`)
    if (!listRes.ok) {
      return defaultModels
    }
    const listData = await listRes.json()
    if (!listData.models || !Array.isArray(listData.models)) {
      return defaultModels
    }
    
    const filtered = listData.models
      .filter((m: any) => {
        const name = m.name.toLowerCase()
        const supportsGen = m.supportedGenerationMethods?.includes('generateContent')
        const isGemini = name.includes('gemini')
        const isExcluded = name.includes('embedding') || name.includes('image') || name.includes('tts') || name.includes('robotics') || name.includes('veo') || name.includes('imagen') || name.includes('lyria') || name.includes('nano') || name.includes('aqa') || name.includes('computer-use') || name.includes('deep-research') || name.includes('antigravity')
        return supportsGen && isGemini && !isExcluded
      })
      .map((m: any) => m.name.replace(/^models\//, ''))

    if (filtered.length === 0) {
      return defaultModels
    }

    const priorityOrder = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemini-pro-latest'
    ]

    function getPriorityIndex(modelName: string) {
      const name = modelName.toLowerCase()
      for (let i = 0; i < priorityOrder.length; i++) {
        if (name.includes(priorityOrder[i])) {
          return i
        }
      }
      return 999
    }

    filtered.sort((a: string, b: string) => {
      const idxA = getPriorityIndex(a)
      const idxB = getPriorityIndex(b)
      return idxA - idxB
    })

    return filtered
  } catch (err) {
    console.warn('[DynamicModels] Exception:', err)
    return defaultModels
  }
}

// Helper to convert ArrayBuffer to Base64 in Deno
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { storage_path, gemini_api_key } = await req.json()
    if (!storage_path) {
      return new Response(JSON.stringify({ error: 'Missing storage_path parameter' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Initialize Supabase Client with User Auth
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // 1. Fetch Gemini API Key
    let activeKey = gemini_api_key
    if (!activeKey) {
      const { data: profile } = await supabaseClient
        .from('users_profile')
        .select('gemini_api_key')
        .maybeSingle()
      activeKey = profile?.gemini_api_key
    }
    // Fallback to Env key if not provided
    if (!activeKey) {
      activeKey = Deno.env.get('GEMINI_API_KEY')
    }

    if (!activeKey) {
      return new Response(JSON.stringify({ error: 'Google Gemini API Key is required. Please set it in Settings.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Download Image from Storage
    const { data: fileData, error: downloadError } = await supabaseClient.storage
      .from('receipts')
      .download(storage_path)

    if (downloadError) {
      throw new Error(`Failed to download receipt image: ${downloadError.message}`)
    }
    if (!fileData) {
      throw new Error('Downloaded receipt data is empty.')
    }

    // Determine MIME type
    let mimeType = fileData.type || 'image/jpeg'
    if (mimeType === 'application/octet-stream') {
      const lowerPath = storage_path.toLowerCase()
      if (lowerPath.endsWith('.png')) mimeType = 'image/png'
      else if (lowerPath.endsWith('.webp')) mimeType = 'image/webp'
      else mimeType = 'image/jpeg'
    }

    // Convert to Base64
    const arrayBuf = await fileData.arrayBuffer()
    const base64Image = arrayBufferToBase64(arrayBuf)

    // 3. Query Gemini API
    const models = await getDynamicModels(activeKey)
    let rawContent = ""
    let lastError: any = null

    for (const model of models) {
      try {
        console.log(`Trying Gemini model ${model} for receipt scan...`)
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${activeKey}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: `Analyze this image (which could be a store receipt, utility bill, restaurant invoice, or a screenshot of a UPI transaction like GPay, PhonePe, Paytm). 
                    Extract the following financial details accurately:
                    1. amount (numeric float value)
                    2. currency (3-letter ISO code, e.g. INR, USD, EUR. Default to INR if it seems Indian, like UPI screenshots)
                    3. category (Categorize into precisely one of these values: Shopping, Groceries, Food & dining, Transport, Bills & recharges, Transfers, Medical, Travel, Repayments, Personal, Services, Insurance, Entertainment, Gaming, Small shops, Rent, Logistics, Subscription, Investment, Fitness, Pet, Miscellaneous)
                    4. description (Brief summary of what was purchased or description of the transaction)
                    5. transaction_date (ISO 8601 string, e.g., '2026-06-01T20:00:00Z'. Extract transaction timestamp, or estimate/use current date if not visible)
                    6. vendor (Name of the shop, store, merchant, or individual who received the money. For UPI, extract the receiver's name)
                    
                    Ensure the response is ONLY a single, clean JSON object without markdown formatting blocks or extra text.
                    JSON structure:
                    {
                    	"amount": 150.00,
                    	"currency": "INR",
                    	"category": "Food & dining",
                    	"description": "Lunch at restaurant",
                    	"transaction_date": "2026-06-01T13:45:00.000Z",
                    	"vendor": "Burger King"
                    }`
                  },
                  {
                    inlineData: {
                      mimeType: mimeType,
                      data: base64Image
                    }
                  }
                ]
              }
            ],
            generationConfig: {
              maxOutputTokens: 1000
            }
          })
        })

        if (response.ok) {
          const resJson = await response.json()
          const text = resJson.candidates?.[0]?.content?.parts?.[0]?.text?.trim()
          if (text) {
            rawContent = text
            break
          }
        } else {
          const errMsg = await response.text()
          console.warn(`Model ${model} failed: ${errMsg}`)
          lastError = new Error(errMsg)
        }
      } catch (err) {
        console.error(`Error calling model ${model}:`, err)
        lastError = err
      }
    }

    if (!rawContent) {
      throw lastError || new Error("No response from Gemini API models.")
    }

    // Extract JSON from markdown wraps
    let cleanJson = rawContent.trim()
    const firstCurly = cleanJson.indexOf('{')
    const lastCurly = cleanJson.lastIndexOf('}')
    if (firstCurly !== -1 && lastCurly !== -1 && lastCurly > firstCurly) {
      cleanJson = cleanJson.substring(firstCurly, lastCurly + 1)
    }

    const parsedData = JSON.parse(cleanJson)

    return new Response(JSON.stringify({
      success: true,
      message: 'Receipt parsed successfully.',
      data: parsedData
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('OCR scanning error:', err)
    return new Response(JSON.stringify({ success: false, error: err.message || err.toString() }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
