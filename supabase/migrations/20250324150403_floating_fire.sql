/*
  # Create inventory items table

  1. New Tables
    - `inventory_items`
      - `id` (uuid, primary key)
      - `name` (text, not null)
      - `category` (text, not null)
      - `description` (text)
      - `rental_price` (numeric(10,2), not null)
      - `acquisition_price` (numeric(10,2))
      - `code` (text, unique, not null)
      - `current_stock` (integer, default 0)
      - `min_stock` (integer, default 0)
      - `status` (text, default 'active')
      - `created_at` (timestamptz, default now())
      - `updated_at` (timestamptz, default now())

  2. Security
    - Enable RLS on `inventory_items` table
    - Add policies for authenticated users to:
      - Read all items
      - Create new items
      - Update existing items
*/

-- Create the inventory_items table if it doesn't exist
CREATE TABLE IF NOT EXISTS inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  description text,
  rental_price numeric(10,2) NOT NULL,
  acquisition_price numeric(10,2),
  code text UNIQUE NOT NULL,
  current_stock integer DEFAULT 0,
  min_stock integer DEFAULT 0,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Enable read access for authenticated users" ON inventory_items;
  DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON inventory_items;
  DROP POLICY IF EXISTS "Enable update access for authenticated users" ON inventory_items;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create policies
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