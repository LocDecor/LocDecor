/*
  # Implement Sequential Order Numbers

  1. Changes
    - Add order_number column to orders table
    - Create sequence for order numbers
    - Add function to generate sequential order numbers
    - Update existing orders with sequential numbers
    - Add trigger to automatically generate numbers for new orders

  2. Security
    - Maintain existing permissions
    - Keep RLS enabled
*/

-- Create sequence for order numbers
CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1;

-- Add order_number column
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS order_number text UNIQUE;

-- Function to format order number
CREATE OR REPLACE FUNCTION format_order_number(num integer)
RETURNS text AS $$
BEGIN
  RETURN 'PN' || LPAD(num::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS trigger AS $$
BEGIN
  -- Get next value from sequence
  NEW.order_number := format_order_number(nextval('order_number_seq'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new orders
CREATE TRIGGER generate_order_number_trigger
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Update existing orders with sequential numbers
WITH numbered_orders AS (
  SELECT 
    id,
    format_order_number(
      ROW_NUMBER() OVER (ORDER BY created_at)::integer
    ) as new_number
  FROM orders
  WHERE order_number IS NULL
)
UPDATE orders o
SET order_number = no.new_number
FROM numbered_orders no
WHERE o.id = no.id;

-- Set order_number as NOT NULL after updating existing records
ALTER TABLE orders
ALTER COLUMN order_number SET NOT NULL;