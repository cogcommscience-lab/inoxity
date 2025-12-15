# Supabase Edge Functions

This directory contains Edge Functions for the Inoxity app.

## Setup

1. Install Supabase CLI: https://supabase.com/docs/guides/cli
2. Link your project: `supabase link --project-ref your-project-ref`
3. Set up environment variables in Supabase Dashboard:
   - Go to Project Settings > Edge Functions > Secrets
   - Add `RESEND_API_KEY` (get one from https://resend.com)

## Email Function Setup

### Option 1: Using Resend (Recommended)

1. Sign up for Resend at https://resend.com
2. Get your API key
3. Add it as a secret in Supabase:
   ```bash
   supabase secrets set RESEND_API_KEY=your_api_key_here
   ```
4. Update the `from` email in `send-opt-out-email/index.ts` with your verified domain
5. Deploy the function:
   ```bash
   supabase functions deploy send-opt-out-email
   ```

### Option 2: Using Other Email Services

You can modify `send-opt-out-email/index.ts` to use other email services:
- SendGrid
- Mailgun
- AWS SES
- Postmark

### Option 3: Using Supabase Database Webhooks

Alternatively, you can set up a database webhook in Supabase that triggers on participant opt-out and sends emails via a third-party service.

## Testing

Test the function locally:
```bash
supabase functions serve send-opt-out-email
```

Then test with:
```bash
curl -X POST http://localhost:54321/functions/v1/send-opt-out-email \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "laasya.m1@gmail.com",
    "subject": "Test",
    "body": "Test email",
    "userId": "test-uuid",
    "deviceUUID": "test-device-uuid"
  }'
```
