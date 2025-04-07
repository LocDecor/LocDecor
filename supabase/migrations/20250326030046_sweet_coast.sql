/*
  # Fix Item Availability System

  1. Changes
    - Drop existing policies first
    - Create item_availability table with proper structure
    - Add optimized functions for availability tracking
    - Add proper indexes for performance

  2. Security
    - Enable RLS on new table
    - Add policies for authenticated users
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Enable read access for authenticated users" ON item_availability;
  DROP POLICY IF EXISTS "Enable write access for authenticated users" ON item_availability;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create item_availability table if it doesn't exist
CREATE TABLE IF NOT EXISTS item_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  date date NOT NULL,
  available_quantity integer NOT NULL,
  reserved_quantity integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT item_availability_item_id_date_key UNIQUE (item_id, date)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_item_availability_date ON item_availability(date);
CREATE INDEX IF NOT EXISTS idx_item_availability_item ON item_availability(item_id);

-- Enable RLS
ALTER TABLE item_availability ENABLE ROW LEVEL SECURITY;

-- Create new policies with unique names
CREATE POLICY "item_availability_select_policy"
  ON item_availability FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "item_availability_all_policy"
  ON item_availability FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Function to update item availability
CREATE OR REPLACE FUNCTION update_item_availability()
RETURNS trigger AS $$
BEGIN
  -- For new orders or date changes
  IF TG_OP = 'INSERT' OR 
     (TG_OP = 'UPDATE' AND 
      (OLD.pickup_date != NEW.pickup_date OR 
       OLD.return_date != NEW.return_date OR
       OLD.order_status != NEW.order_status)) THEN

    -- Update availability for each day in the order period
    WITH date_range AS (
      SELECT generate_series(
        NEW.pickup_date::date,
        NEW.return_date::date,
        '1 day'::interval
      )::date AS date
    ),
    order_items_data AS (
      SELECT 
        oi.item_id,
        oi.quantity,
        i.current_stock
      FROM order_items oi
      JOIN inventory_items i ON i.id = oi.item_id
      WHERE oi.order_id = NEW.id
    )
    INSERT INTO item_availability (
      item_id,
      date,
      available_quantity,
      reserved_quantity
    )
    SELECT 
      d.item_id,
      dr.date,
      d.current_stock as available_quantity,
      COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
        THEN oi.quantity ELSE 0 END
      ), 0) as reserved_quantity
    FROM order_items_data d
    CROSS JOIN date_range dr
    LEFT JOIN order_items oi ON oi.item_id = d.item_id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND dr.date BETWEEN o.pickup_date AND o.return_date
    GROUP BY d.item_id, dr.date, d.current_stock
    ON CONFLICT (item_id, date) 
    DO UPDATE SET
      available_quantity = EXCLUDED.available_quantity,
      reserved_quantity = EXCLUDED.reserved_quantity,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for availability updates
DROP TRIGGER IF EXISTS update_item_availability_trigger ON orders;
CREATE TRIGGER update_item_availability_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_item_availability();

-- Function to initialize availability data
CREATE OR REPLACE FUNCTION initialize_item_availability(
  start_date date DEFAULT CURRENT_DATE,
  days integer DEFAULT 90
)
RETURNS void AS $$
BEGIN
  -- Generate availability data for all items
  WITH date_range AS (
    SELECT generate_series(
      start_date,
      start_date + (days || ' days')::interval,
      '1 day'::interval
    )::date AS date
  ),
  items_data AS (
    SELECT 
      i.id as item_id,
      i.current_stock,
      d.date,
      COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
        THEN oi.quantity ELSE 0 END
      ), 0) as reserved_quantity
    FROM inventory_items i
    CROSS JOIN date_range d
    LEFT JOIN order_items oi ON oi.item_id = i.id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND d.date BETWEEN o.pickup_date AND o.return_date
    GROUP BY i.id, i.current_stock, d.date
  )
  INSERT INTO item_availability (
    item_id,
    date,
    available_quantity,
    reserved_quantity
  )
  SELECT 
    item_id,
    date,
    current_stock as available_quantity,
    reserved_quantity
  FROM items_data
  ON CONFLICT (item_id, date) 
  DO UPDATE SET
    available_quantity = EXCLUDED.available_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    updated_at = now();
END;
$$ LANGUAGE plpgsql;

-- Initialize availability data for next 90 days
SELECT initialize_item_availability();