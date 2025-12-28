Supabase Server-side Delete User (example)

This folder contains an example of a secure server-side endpoint that deletes the calling user's account using Supabase "service_role" key. DO NOT put the service_role key in a client app — keep it on the server only.

Edge Function (Deno / Supabase Functions) example (TypeScript):

index.ts

```ts
// Example Supabase Edge Function (Deno) - delete current user
import { serve } from "std/server";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!;

serve(async (req) => {
  // validate Authorization bearer token from client
  const authHeader = req.headers.get('authorization');
  if (!authHeader) return new Response('Missing auth', { status: 401 });

  // Validate the token by calling Supabase auth endpoint
  const userResp = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { 'Authorization': authHeader }});
  if (!userResp.ok) return new Response('Invalid token', { status: 403 });
  const userData = await userResp.json();
  const userId = userData.id;

  // Call Supabase admin users API to delete user
  const deleteResp = await fetch(`${SUPABASE_URL}/admin/v1/users/${userId}`, {
    method: 'DELETE',
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` },
  });

  if (!deleteResp.ok) {
    const body = await deleteResp.text();
    return new Response(`Delete failed: ${deleteResp.status} ${body}`, { status: 500 });
  }

  // Optionally, remove related rows (profiles, documents) using Postgres via the service role
  // Here we assume rows are cascade-deleted or rely on DB FK cascade; otherwise, call the PostgREST API to delete rows.

  return new Response('User deleted', { status: 200 });
});
```

Deployment / security notes:
- Set environment variables `SUPABASE_URL` and `SERVICE_ROLE_KEY` in your function provider (do not commit service_role key to git).
- The function validates the caller by forwarding the Authorization Bearer <token> to Supabase `/auth/v1/user` endpoint which returns the calling user id.
- The function uses the service role key to call the Admin API to delete the user.
- This example deletes the auth user only. Consider deleting related rows (profiles, documents, storage files) as part of the cleanup — either rely on DB cascades or call the admin PostgREST endpoints authenticated with the service role key.

Client usage (Flutter):
- Set `lib/core/constants/server_config.dart` `USER_DELETE_ENDPOINT` to your deployed function URL.
- Confirm deletion in-app; the client will call POST `${USER_DELETE_ENDPOINT}` with Authorization: Bearer <access_token> header.
- On success, the app signs out and returns to the login screen.

Test locally:
- Use `curl` with an Authorization header containing a user's access token to validate behavior.

```
curl -X POST https://<your-deploy>/delete-user -H "Authorization: Bearer <USER_ACCESS_TOKEN>"
```

This is an example — adapt to your security requirements and cloud provider. Ensure you protect the service_role key and validate requests.