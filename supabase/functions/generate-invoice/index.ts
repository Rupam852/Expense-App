import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"
import { PDFDocument, rgb, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1"
import { corsHeaders } from "../_shared/cors.ts"

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

    // Initialize Supabase Client with User Auth
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { expense_ids, expenses: rawExpenses, month_year } = await req.json()
    let expenses = []

    if (rawExpenses && Array.isArray(rawExpenses) && rawExpenses.length > 0) {
      expenses = rawExpenses.filter((e: any) => !e.is_deleted && !e.isDeleted)
      expenses.sort((a: any, b: any) => {
        const dateA = new Date(a.transaction_date || a.transactionDate || 0).getTime()
        const dateB = new Date(b.transaction_date || b.transactionDate || 0).getTime()
        return dateB - dateA
      })
    } else {
      if (!expense_ids || !Array.isArray(expense_ids) || expense_ids.length === 0) {
        return new Response(JSON.stringify({ error: 'No expenses or expense IDs provided' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // Fetch Selected Expenses from DB
      const { data: dbExpenses, error: expensesError } = await supabaseClient
        .from('expenses')
        .select('*')
        .in('id', expense_ids)
        .eq('is_deleted', false)
        .order('transaction_date', { ascending: false })

      if (expensesError) throw expensesError
      expenses = dbExpenses || []
    }

    if (!expenses || expenses.length === 0) {
      return new Response(JSON.stringify({ error: 'No valid expenses found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Fetch User Profile
    const { data: profile } = await supabaseClient
      .from('users_profile')
      .select('*')
      .maybeSingle()

    // 3. Fetch User Auth metadata for email
    const { data: { user } } = await supabaseClient.auth.getUser()
    const email = user?.email || 'N/A'
    const name = profile?.name || user?.user_metadata?.name || 'Valued Member'

    // 4. Fetch Payment details
    const { data: paymentDetails } = await supabaseClient
      .from('payment_details')
      .select('upi_id')
      .limit(1)
    const upiId = paymentDetails?.[0]?.upi_id || 'Not specified'

    // Fetch exchange rates
    let rates = { INR: 1.0, USD: 0.012, EUR: 0.011, GBP: 0.0094, AUD: 0.018, CAD: 0.016 }
    try {
      const rateRes = await fetch('https://open.er-api.com/v6/latest/INR')
      if (rateRes.ok) {
        const rateData = await rateRes.json()
        if (rateData.result === 'success' && rateData.rates) {
          rates = rateData.rates
        }
      }
    } catch (err) {
      console.warn('Failed to fetch live exchange rates, using defaults:', err)
    }

    // 5. Initialize pdf-lib Document
    const pdfDoc = await PDFDocument.create()
    const helvetica = await pdfDoc.embedFont(StandardFonts.Helvetica)
    const helveticaBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold)

    // Page state
    let page = pdfDoc.addPage([595, 842]) // A4 Size
    let { width, height } = page.getSize()

    const primaryColor = rgb(0.0, 0.816, 0.612) // Groww Green (#00D09C)
    const textColor = rgb(0.1, 0.12, 0.17)
    const greyColor = rgb(0.46, 0.46, 0.46)
    const lightGreyColor = rgb(0.88, 0.91, 0.94)

    // Helper to draw Header
    const drawHeader = (p: typeof page) => {
      // Accent banner
      p.drawText('GROW EXPENSE', { x: 50, y: 780, size: 22, font: helveticaBold, color: primaryColor })
      p.drawText('Official Reimbursement & Billing Statement', { x: 50, y: 765, size: 10, font: helvetica, color: greyColor })
      
      // Divider
      p.drawLine({
        start: { x: 50, y: 750 },
        end: { x: 545, y: 750 },
        thickness: 1,
        color: lightGreyColor,
      })
    }

    drawHeader(page)

    // User details section
    page.drawText(`Issued By: ${name}`, { x: 50, y: 725, size: 10, font: helveticaBold, color: textColor })
    page.drawText(`Email: ${email}`, { x: 50, y: 710, size: 10, font: helvetica, color: textColor })
    page.drawText(`Date of Issue: ${new Date().toLocaleDateString()}`, { x: 50, y: 695, size: 10, font: helvetica, color: textColor })
    page.drawText(`UPI ID for Repayment: ${upiId}`, { x: 350, y: 725, size: 10, font: helveticaBold, color: textColor })

    // Table Header
    const tableTop = 650
    page.drawText('Date', { x: 50, y: tableTop, size: 10, font: helveticaBold, color: greyColor })
    page.drawText('Category', { x: 140, y: tableTop, size: 10, font: helveticaBold, color: greyColor })
    page.drawText('Description', { x: 230, y: tableTop, size: 10, font: helveticaBold, color: greyColor })
    page.drawText('Amount', { x: 480, y: tableTop, size: 10, font: helveticaBold, color: greyColor })

    page.drawLine({
      start: { x: 50, y: tableTop - 8 },
      end: { x: 545, y: tableTop - 8 },
      thickness: 1.5,
      color: greyColor,
    })

    let currentY = tableTop - 25
    let totalSum = 0.0

    for (const exp of expenses) {
      if (currentY < 80) {
        page = pdfDoc.addPage([595, 842])
        drawHeader(page)
        // Table Header on new page
        const newTableTop = 720
        page.drawText('Date', { x: 50, y: newTableTop, size: 10, font: helveticaBold, color: greyColor })
        page.drawText('Category', { x: 140, y: newTableTop, size: 10, font: helveticaBold, color: greyColor })
        page.drawText('Description', { x: 230, y: newTableTop, size: 10, font: helveticaBold, color: greyColor })
        page.drawText('Amount', { x: 480, y: newTableTop, size: 10, font: helveticaBold, color: greyColor })
        page.drawLine({
          start: { x: 50, y: newTableTop - 8 },
          end: { x: 545, y: newTableTop - 8 },
          thickness: 1.5,
          color: greyColor,
        })
        currentY = newTableTop - 25
      }

      const dateStr = new Date(exp.transaction_date || exp.transactionDate).toLocaleDateString()
      const amountNum = parseFloat(exp.amount) || 0.0
      const amountStr = `${amountNum.toFixed(2)} ${exp.currency}`
      
      const rate = rates[exp.currency.toUpperCase() as keyof typeof rates] || 1.0
      const amountInINR = rate !== 0 ? (amountNum / rate) : amountNum
      totalSum += amountInINR

      page.drawText(dateStr, { x: 50, y: currentY, size: 9, font: helvetica, color: textColor })
      page.drawText(exp.category, { x: 140, y: currentY, size: 9, font: helvetica, color: textColor })
      
      // Clean and truncate description
      const descVal = exp.description || 'N/A'
      const truncatedDesc = descVal.length > 35 ? descVal.substring(0, 32) + '...' : descVal
      page.drawText(truncatedDesc, { x: 230, y: currentY, size: 9, font: helvetica, color: textColor })
      
      page.drawText(amountStr, { x: 480, y: currentY, size: 9, font: helvetica, color: textColor })

      page.drawLine({
        start: { x: 50, y: currentY - 5 },
        end: { x: 545, y: currentY - 5 },
        thickness: 0.5,
        color: rgb(0.95, 0.95, 0.95),
      })

      currentY -= 20
    }

    // Total section
    if (currentY < 100) {
      page = pdfDoc.addPage([595, 842])
      drawHeader(page)
      currentY = 720
    }

    currentY -= 10
    page.drawLine({
      start: { x: 350, y: currentY },
      end: { x: 545, y: currentY },
      thickness: 1.5,
      color: rgb(0.65, 0.95, 0.82),
    })

    page.drawText('Total Expenses:', { x: 330, y: currentY - 20, size: 11, font: helveticaBold, color: textColor })
    page.drawText(`${totalSum.toFixed(2)} INR`, { x: 450, y: currentY - 20, size: 12, font: helveticaBold, color: primaryColor })

    // Footer on all pages helper
    const pagesList = pdfDoc.getPages()
    pagesList.forEach((p) => {
      const footerY = 40
      p.drawLine({
        start: { x: 50, y: footerY + 15 },
        end: { x: 545, y: footerY + 15 },
        thickness: 1,
        color: lightGreyColor,
      })
      p.drawText('Generated instantly by Grow Expense App. For any discrepancies, contact issuer above.', {
        x: 90,
        y: footerY,
        size: 8,
        font: helvetica,
        color: greyColor,
      })
    })

    const pdfBytes = await pdfDoc.save()
    const base64Pdf = arrayBufferToBase64(pdfBytes)

    return new Response(JSON.stringify({
      success: true,
      pdf_base64: base64Pdf,
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    })
  } catch (err) {
    console.error('Invoice PDF generation error:', err)
    return new Response(JSON.stringify({ error: err.message || err.toString() }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}
