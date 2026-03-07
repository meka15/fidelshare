# Supabase Edge Functions

## send_push

This function sends FCM push notifications to all device tokens registered in the `device_tokens` table for a given `section`, excluding the sender.

### Required secrets

Set these in your Supabase project (Edge Function secrets):

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FCM_SERVER_KEY` (Firebase legacy server key)

### Deploy

From the project root (after installing Supabase CLI):

- `supabase login`
- `supabase link --project-ref <your-project-ref>`
- `supabase functions deploy send_push`
- `supabase secrets set FCM_SERVER_KEY=...`

### Test

Call it from the app by sending a chat message, or via curl:

- `curl -i -X POST '<SUPABASE_URL>/functions/v1/send_push' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <anon-or-user-jwt>' \
  -d '{"section":"2","exclude_user_id":"...","title":"Test","body":"Hello","type":"chat","data":{}}'`

