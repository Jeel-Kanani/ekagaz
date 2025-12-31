-- Add 'phone' column to profiles table if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone text;

-- Add 'phone_verified' column to profiles table if it doesn't exist (used in ProfileProvider)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_verified boolean DEFAULT false;

-- Force a schema cache reload (optional, but good practice if errors persist)
NOTIFY pgrst, 'reload config';
