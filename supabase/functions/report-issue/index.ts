import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { name, email, category, message, errorDetails, deviceInfo, appVersion } = await req.json()

    if (!message || !email) {
      return new Response(
        JSON.stringify({ error: 'Message and email are required.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const senderEmail = email || 'anonymous@growexpense.app'
    const senderName = name || 'Grow Expense User'
    const issueCategory = category || 'General Support / Bug Report'
    const targetEmail = 'rupambairagiya08@gmail.com'

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0F172A; color: #F8FAFC; margin: 0; padding: 20px; }
          .card { background-color: #1E293B; border-radius: 16px; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #334155; }
          .header { border-bottom: 1px solid #334155; padding-bottom: 16px; margin-bottom: 20px; }
          .badge { background: #00D09C; color: #000; font-size: 12px; font-weight: bold; padding: 4px 10px; border-radius: 20px; display: inline-block; }
          .title { font-size: 20px; font-weight: bold; margin-top: 10px; color: #FFFFFF; }
          .section { margin-bottom: 16px; }
          .section-label { font-size: 12px; font-weight: bold; text-transform: uppercase; color: #94A3B8; margin-bottom: 4px; }
          .section-val { font-size: 14px; color: #E2E8F0; background: #0F172A; padding: 12px; border-radius: 8px; border: 1px solid #334155; white-space: pre-wrap; word-break: break-word; }
          .error-box { background: #450A0A; border: 1px solid #991B1B; color: #FCA5A5; font-family: monospace; font-size: 12px; padding: 12px; border-radius: 8px; white-space: pre-wrap; word-break: break-word; }
          .footer { font-size: 11px; color: #64748B; text-align: center; margin-top: 24px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <span class="badge">${issueCategory}</span>
            <div class="title">🚨 Grow Expense Issue / Help Request</div>
          </div>
          <div class="section">
            <div class="section-label">User Details</div>
            <div class="section-val"><strong>Name:</strong> ${senderName}<br><strong>Email:</strong> ${senderEmail}</div>
          </div>
          <div class="section">
            <div class="section-label">User Description / Message</div>
            <div class="section-val">${message}</div>
          </div>
          ${errorDetails ? `
          <div class="section">
            <div class="section-label">Error Log / Technical Details</div>
            <div class="error-box">${errorDetails}</div>
          </div>
          ` : ''}
          ${deviceInfo || appVersion ? `
          <div class="section">
            <div class="section-label">Device & App Context</div>
            <div class="section-val"><strong>App Version:</strong> ${appVersion || 'v1.0.0'}<br><strong>Device / Platform:</strong> ${deviceInfo || 'Unknown'}</div>
          </div>
          ` : ''}
          <div class="footer">
            Received via Grow Expense App Support Dispatcher • Sent to ${targetEmail}
          </div>
        </div>
      </body>
      </html>
    `

    // Try sending via Apps Script or Resend / SMTP if configured
    const emailApiUrl = Deno.env.get('EMAIL_API_URL')
    if (emailApiUrl) {
      await fetch(emailApiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: targetEmail,
          subject: `[Grow Expense Help] ${issueCategory} - from ${senderName}`,
          html: htmlContent
        }),
      })
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Report submitted successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
