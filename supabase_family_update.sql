-- 1. Add 'invite_code' and 'description' to families table
ALTER TABLE families ADD COLUMN invite_code text;
ALTER TABLE families ADD COLUMN description text;

-- 2. Make invite_code unique (it's okay if multiple rows are null initially)
ALTER TABLE families ADD CONSTRAINT families_invite_code_key UNIQUE (invite_code);

-- 3. (Optional) Function to generate a random 6-digit code for existing families that don't have one
-- You can run this block if you want to backfill, otherwise new logic will handle new families.
-- UPDATE families SET invite_code = floor(random() * (999999 - 100000 + 1) + 100000)::text WHERE invite_code IS NULL;
