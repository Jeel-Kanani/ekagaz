-- Add 'dp_url' column to families table if it doesn't exist
ALTER TABLE families ADD COLUMN IF NOT EXISTS dp_url text;

-- Force a schema cache reload
NOTIFY pgrst, 'reload config';
