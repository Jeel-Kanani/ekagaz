// Server-side configuration placeholders. Replace with your deployed function URL.
const String USER_DELETE_ENDPOINT = 'https://example.com/delete-user';

// If you set USER_DELETE_ENDPOINT to your deployed serverless function, the app will
// call that endpoint to securely request account deletion. The function must verify
// the caller's JWT and use a Supabase service_role key to perform admin deletion.
