/*
  # Fix Item Availability Implementation

  1. Changes
    - Drop existing item_availability table and related objects
    - Create new item_availability table with proper structure
    - Add optimized functions and triggers
    - Fix permission issues

  2. Security
    - Maintain RLS policies
    - Keep existing permissions
*/

-- Drop existing objects
DROP TABLE IF EXISTS item_availability CASCADE;
DROP FUNCTION IF EXISTS update_item_availability() CASCADE;
DROP FUNCTION IF EXISTS initialize_item_availability() CASCADE;

-- Create item_availability table
CREATE TABLE item_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  date date NOT NULL,
  available_quantity integer NOT NULL,
  reserved_quantity integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT item_availability_item_id_date_key UNIQUE (item_id, date)
);

-- Create indexes
CREATE INDEX idx_item_availability_date ON item_availability(date);
CREATE INDEX idx_item_availability_item ON item_availability(item_id);

-- Enable RLS
ALTER TABLE item_availability ENABLE ROW LEVEL SECURITY;

-- Create policies with unique names
CREATE POLICY "item_availability_read_policy"
  ON item_availability FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "item_availability_modify_policy"
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

    -- Update availability for affected items
    WITH date_range AS (
      SELECT generate_series(
        NEW.pickup_date::date,
        NEW.return_date::date,
        '1 day'::interval
      )::date AS date
    ),
    affected_items AS (
      SELECT 
        oi.item_id,
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
      ai.item_id,
      d.date,
      ai.current_stock as available_quantity,
      COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
        THEN oi.quantity ELSE 0 END
      ), 0) as reserved_quantity
    FROM affected_items ai
    CROSS JOIN date_range d
    LEFT JOIN order_items oi ON oi.item_id = ai.item_id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND d.date BETWEEN o.pickup_date AND o.return_date
    GROUP BY ai.item_id, d.date, ai.current_stock
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
CREATE TRIGGER update_item_availability_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_item_availability();

-- Function to initialize availability data
CREATE OR REPLACE FUNCTION initialize_item_availability()
RETURNS void AS $$
BEGIN
  -- Generate availability data for next 90 days
  WITH date_range AS (
    SELECT generate_series(
      CURRENT_DATE,
      CURRENT_DATE + interval '90 days',
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

-- Initialize availability data
SELECT initialize_item_availability();