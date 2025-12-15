// Supabase Edge Function to send opt-out emails
// Deploy this function to your Supabase project:
// supabase functions deploy send-opt-out-email

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from "https://esm.sh/resend@2.0.0"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || ""

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    })
  }

  try {
    const { to, subject, body, userId, deviceUUID } = await req.json()

    if (!to || !subject || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, subject, body" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      )
    }

    // If Resend API key is configured, use Resend
    if (RESEND_API_KEY) {
      const resend = new Resend(RESEND_API_KEY)
      
      const { data, error } = await resend.emails.send({
        from: "Inoxity Study <noreply@yourdomain.com>", // Update with your verified domain
        to: [to],
        subject: subject,
        html: `
          <h2>Participant Opt-Out Notification</h2>
          <p>${body.replace(/\n/g, "<br>")}</p>
          <hr>
          <p style="color: #666; font-size: 12px;">
            This is an automated notification from the Inoxity research study app.
          </p>
        `,
        text: body,
      })

      if (error) {
        console.error("Resend error:", error)
        return new Response(
          JSON.stringify({ error: "Failed to send email", details: error }),
          {
            status: 500,
            headers: { "Content-Type": "application/json" },
          }
        )
      }

      return new Response(
        JSON.stringify({ success: true, messageId: data?.id }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      )
    } else {
      // Fallback: Log the email (for development/testing)
      console.log("Email would be sent:", { to, subject, body, userId, deviceUUID })
      
      return new Response(
        JSON.stringify({
          success: true,
          message: "Email logged (RESEND_API_KEY not configured)",
          note: "Configure RESEND_API_KEY in Supabase dashboard to enable email sending",
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      )
    }
  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    )
  }
})
