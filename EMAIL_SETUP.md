# Email Setup Guide

The app sends opt-out emails when participants choose to delete their data. You have two options:

## Option 1: EmailJS (Recommended - Easiest Setup)

EmailJS is a free service that allows you to send emails directly from your app without a backend server.

### Setup Steps:

1. **Sign up for EmailJS** (free tier available):
   - Go to https://www.emailjs.com/
   - Create a free account

2. **Create an Email Service**:
   - In EmailJS dashboard, go to "Email Services"
   - Click "Add New Service"
   - Choose your email provider (Gmail, Outlook, etc.) or use "Custom SMTP"
   - Follow the setup instructions
   - **Copy the Service ID** (e.g., `service_abc123`)

3. **Create an Email Template**:
   - Go to "Email Templates"
   - Click "Create New Template"
   - Set up your template with these variables:
     - `{{to_email}}` - Recipient email
     - `{{subject}}` - Email subject
     - `{{message}}` - Email body/message
     - `{{user_id}}` - User ID
     - `{{device_uuid}}` - Device UUID
   - **Copy the Template ID** (e.g., `template_xyz789`)

4. **Get your Public Key**:
   - Go to "Account" > "General"
   - **Copy your Public Key** (e.g., `abcdefghijklmnop`)

5. **Add to Config.plist**:
   - Open `Inoxity/Config.plist` (or create it from `Config.example.plist`)
   - Add these three keys with your values:
     ```xml
     <key>EmailJSServiceID</key>
     <string>service_abc123</string>
     <key>EmailJSTemplateID</key>
     <string>template_xyz789</string>
     <key>EmailJSPublicKey</key>
     <string>abcdefghijklmnop</string>
     ```

6. **Test it**:
   - Run the app and test the opt-out flow
   - Check your email inbox (laasya.m1@gmail.com)

### Example EmailJS Template:

**Subject:** `{{subject}}`

**Content:**
```
{{message}}
```

That's it! The app will automatically use EmailJS to send emails.

---

## Option 2: Supabase Edge Functions

If you prefer to use Supabase Edge Functions, see `supabase/functions/README.md` for setup instructions.

The app will try the Edge Function first, then fall back to EmailJS if the Edge Function is not available.

---

## Troubleshooting

### Not receiving emails?

1. **Check Xcode console logs**:
   - Look for messages starting with `✅`, `⚠️`, or `❌`
   - These will tell you if the email was sent or if there was an error

2. **Verify EmailJS configuration**:
   - Make sure all three values (Service ID, Template ID, Public Key) are correct in `Config.plist`
   - Check that your EmailJS account is active

3. **Check spam folder**:
   - Emails might go to spam initially

4. **Test EmailJS directly**:
   - Go to EmailJS dashboard > "Test" tab
   - Try sending a test email to verify your setup

5. **Check email service limits**:
   - Free EmailJS tier has limits (200 emails/month)
   - Make sure you haven't exceeded the limit

### Still having issues?

Check the Xcode console for detailed error messages. The app will print:
- `✅` - Success messages
- `⚠️` - Warnings (email failed but opt-out succeeded)
- `❌` - Errors (with details)
