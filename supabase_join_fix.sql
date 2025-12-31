-- 1. Backfill missing invite codes for existing families
-- We use a random 6-char string (uppercase)
UPDATE families 
SET invite_code = upper(substring(md5(random()::text) from 1 for 6)) 
WHERE invite_code IS NULL;

-- 2. Create a secure function to find a family by Code or ID
-- This bypasses RLS so users can find a family to join without being a member yet
CREATE OR REPLACE FUNCTION find_family_id(identifier text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  found_id uuid;
BEGIN
  -- 1. Try to match by invite_code (case insensitive check done by caller, but we can force upper)
  SELECT id INTO found_id 
  FROM families 
  WHERE invite_code = identifier 
  LIMIT 1;
  
  IF found_id IS NOT NULL THEN
    RETURN found_id;
  END IF;

  -- 2. If not found, try to match by ID (if it looks like a UUID)
  -- We use a regex check or exception handling to avoid casting errors
  BEGIN
    SELECT id INTO found_id 
    FROM families 
    WHERE id = identifier::uuid 
    LIMIT 1;
  EXCEPTION WHEN invalid_text_representation THEN
    -- Input was not a UUID, so we just return NULL
    RETURN NULL;
  END;

  RETURN found_id;
END;
$$;
