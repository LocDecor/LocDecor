/*
  # Fix RLS policies for clients table

  1. Changes
    - Drop existing policies
    - Create new, more permissive policies for authenticated users
    - Ensure full CRUD access for authenticated users

  2. Security
    - Maintain RLS enabled
    - Allow authenticated users to perform all operations
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON clients;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON clients;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON clients;

-- Create new, more permissive policies
CREATE POLICY "Enable full access for authenticated users" ON clients
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);