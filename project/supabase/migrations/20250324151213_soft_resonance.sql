/*
  # Add item photos table

  1. New Tables
    - `item_photos`
      - `id` (uuid, primary key)
      - `item_id` (uuid, foreign key to inventory_items)
      - `url` (text, not null)
      - `created_at` (timestamptz, default now())

  2. Storage
    - Create bucket for inventory photos

  3. Security
    - Enable RLS on `item_photos` table
    - Add policies for authenticated users
*/

-- Create storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name)
VALUES ('inventory', 'inventory')
ON CONFLICT (id) DO NOTHING;

-- Create the item_photos table
CREATE TABLE IF NOT EXISTS item_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
  url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE item_photos ENABLE ROW LEVEL SECURITY;

-- Create policies for item_photos
CREATE POLICY "Enable read access for authenticated users"
  ON item_photos
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON item_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable delete access for authenticated users"
  ON item_photos
  FOR DELETE
  TO authenticated
  USING (true);

-- Storage policies
CREATE POLICY "Enable read access for all users"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'inventory');

CREATE POLICY "Enable insert access for authenticated users"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'inventory');

CREATE POLICY "Enable update access for authenticated users"
  ON storage.objects FOR UPDATE
  TO authenticated
  WITH CHECK (bucket_id = 'inventory');

CREATE POLICY "Enable delete access for authenticated users"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'inventory');