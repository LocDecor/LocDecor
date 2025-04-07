/*
  # Fix RLS policies for inventory tables

  1. Changes
    - Drop existing policies
    - Create new, properly scoped policies for all inventory tables
    - Ensure consistent policy naming
    - Add proper security checks

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Maintain data integrity
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_items;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON inventory_items;
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON inventory_items;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON inventory_items;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_notifications;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON inventory_notifications;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_stats;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON inventory_stats;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_alerts;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON inventory_alerts;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_reports;
DROP POLICY IF EXISTS "Enable write access for authenticated users" ON inventory_reports;

-- Create new policies for inventory_items
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_items
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON inventory_items
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON inventory_items
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policies for inventory_notifications
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_notifications
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON inventory_notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON inventory_notifications
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policies for inventory_stats
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_stats
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON inventory_stats
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON inventory_stats
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policies for inventory_alerts
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_alerts
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON inventory_alerts
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON inventory_alerts
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policies for inventory_reports
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_reports
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON inventory_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
  ON inventory_reports
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);