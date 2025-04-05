/*
  # Fix Item Availability Policies

  1. Changes
    - Drop existing policies with conflicting names
    - Create new policies with unique names
    - Keep existing table structure and functions
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Enable read access for authenticated users" ON item_availability;
  DROP POLICY IF EXISTS "Enable write access for authenticated users" ON item_availability;
  DROP POLICY IF EXISTS "item_availability_read_policy" ON item_availability;
  DROP POLICY IF EXISTS "item_availability_modify_policy" ON item_availability;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies with unique names
CREATE POLICY "item_availability_select_policy_v2"
  ON item_availability FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "item_availability_modify_policy_v2"
  ON item_availability FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);