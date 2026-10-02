import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"
import { corsHeaders } from "../_shared/cors.ts"

// Initialize Firebase Admin SDK for Deno
import admin from "npm:firebase-admin@^12.0.0"

const serviceAccount = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "{}"
)

if (!admin.apps.length && serviceAccount.project_id) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const {
      userId,
      fcmToken,
      title,
      body,
      data,
      broadcast = false,
      channelId = 'general_alerts_channel'
    } = await req.json()

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: 'Title and body are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let targetTokens: string[] = []

    if (fcmToken) {
      targetTokens.push(fcmToken)
    } else if (broadcast) {
      // Fetch all user tokens from users_profile
      const { data: profiles, error } = await supabase
        .from('users_profile')
        .select('fcm_token')
        .not('fcm_token', 'is', null)

      if (error) throw error
      targetTokens = profiles
        .map((p: any) => p.fcm_token)
        .filter((t: any) => typeof t === 'string' && t.trim().length > 10)
    } else if (userId) {
      // Fetch specific user's token
      const { data: profile, error } = await supabase
        .from('users_profile')
        .select('fcm_token')
        .eq('id', userId)
        .maybeSingle()

      if (error) throw error
      if (profile?.fcm_token) {
        targetTokens.push(profile.fcm_token)
      }
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'No valid FCM device tokens found for recipient.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Prepare FCM payload
    const payloadData: Record<string, string> = {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      channel_id: channelId,
      ...(data || {}),
    }

    // Ensure all data values are string format for FCM protocol
    Object.keys(payloadData).forEach((key) => {
      if (typeof payloadData[key] !== 'string') {
        payloadData[key] = JSON.stringify(payloadData[key])
      }
    })

    const messagePayload = {
      notification: {
        title,
        body,
      },
      data: payloadData,
      android: {
        priority: 'high' as const,
        notification: {
          channelId: channelId,
          icon: 'ic_launcher',
          color: '#00D09C',
          sound: 'default',
          priority: 'max' as const,
        },
      },
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens: targetTokens,
      ...messagePayload,
    })

    return new Response(
      JSON.stringify({
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
