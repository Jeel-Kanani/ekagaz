-- FamVault Supabase SQL Migration Script
-- Run this in your Supabase SQL Editor
-- This script creates the audit_logs table for Week 9 Security & Permissions feature

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL, -- 'create', 'update', 'delete', 'view', 'download'
  entity_type TEXT NOT NULL, -- 'document', 'folder', 'family'
  entity_id TEXT NOT NULL,
  entity_name TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only view their own audit logs or audit logs for entities they have access to
CREATE POLICY "Users can view audit logs for their family"
  ON audit_logs
  FOR SELECT
  USING (
    -- Users can see their own actions
    auth.uid() = user_id
    OR
    -- Users can see actions on documents/folders in their family
    EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM documents d
        WHERE d.id::text = audit_logs.entity_id
        AND d.family_id = fm.family_id
      )
    )
    OR
    EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM folders f
        WHERE f.id::text = audit_logs.entity_id
        AND f.family_id = fm.family_id
      )
    )
  );

-- Policy: Users can insert their own audit logs
CREATE POLICY "Users can insert their own audit logs"
  ON audit_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Optional: Add version columns to existing tables if they don't exist
-- (These are used for conflict resolution in sync)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'documents' AND column_name = 'version') THEN
    ALTER TABLE documents ADD COLUMN version INTEGER DEFAULT 1;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'folders' AND column_name = 'version') THEN
    ALTER TABLE folders ADD COLUMN version INTEGER DEFAULT 1;
  END IF;
END $$;

