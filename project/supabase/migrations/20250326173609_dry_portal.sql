/*
  # Fix Schema Permissions

  1. Changes
    - Grant proper permissions on public schema
    - Grant table permissions to authenticated role
    - Fix permission denied errors

  2. Security
    - Maintain RLS policies
    - Keep existing security model
*/

-- Grant schema usage to authenticated role
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Grant table permissions to authenticated role
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO authenticated;

-- Grant limited permissions to anon role
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Ensure new objects inherit the same grants
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE ON SEQUENCES TO anon;