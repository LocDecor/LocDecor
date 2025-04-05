/*
  # Implement inventory control system

  1. New Tables
    - `item_availability`
      - Tracks item availability for specific dates
      - Links to orders and inventory items
      - Stores reservation periods

  2. Changes
    - Add availability check functions
    - Add triggers for reservation management
    - Add functions for stock calculations

  3. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create item_availability table
CREATE TABLE IF NOT EXISTS item_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  quantity integer NOT NULL,
  pickup_date date NOT NULL,
  return_date date NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE item_availability ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
  ON item_availability
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON item_availability
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable delete access for authenticated users"
  ON item_availability
  FOR DELETE
  TO authenticated
  USING (true);

-- Function to check item availability
CREATE OR REPLACE FUNCTION check_item_availability(
  p_item_id uuid,
  p_quantity integer,
  p_pickup_date date,
  p_return_date date,
  p_current_order_id uuid DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
  total_reserved integer;
  item_stock integer;
BEGIN
  -- Get item's total stock
  SELECT current_stock INTO item_stock
  FROM inventory_items
  WHERE id = p_item_id;

  -- Calculate total reserved quantity for the period
  SELECT COALESCE(SUM(quantity), 0) INTO total_reserved
  FROM item_availability ia
  JOIN orders o ON ia.order_id = o.id
  WHERE ia.item_id = p_item_id
    AND o.order_status NOT IN ('canceled', 'completed')
    AND ia.order_id != COALESCE(p_current_order_id, '00000000-0000-0000-0000-000000000000')
    AND (
      (ia.pickup_date, ia.return_date) OVERLAPS (p_pickup_date, p_return_date)
    );

  -- Check if enough stock is available
  RETURN (item_stock - total_reserved) >= p_quantity;
END;
$$ LANGUAGE plpgsql;

-- Function to manage item reservations
CREATE OR REPLACE FUNCTION manage_item_reservations()
RETURNS TRIGGER AS $$
BEGIN
  -- For new orders
  IF TG_OP = 'INSERT' THEN
    -- Check availability for each item
    IF NOT (
      SELECT bool_and(
        check_item_availability(
          item_id,
          quantity,
          NEW.pickup_date,
          NEW.return_date
        )
      )
      FROM order_items
      WHERE order_id = NEW.id
    ) THEN
      RAISE EXCEPTION 'Um ou mais itens não estão disponíveis para o período selecionado';
    END IF;

    -- Create availability records
    INSERT INTO item_availability (
      item_id,
      order_id,
      quantity,
      pickup_date,
      return_date
    )
    SELECT
      item_id,
      NEW.id,
      quantity,
      NEW.pickup_date,
      NEW.return_date
    FROM order_items
    WHERE order_id = NEW.id;

  -- For updates
  ELSIF TG_OP = 'UPDATE' THEN
    -- If dates changed, check availability
    IF NEW.pickup_date != OLD.pickup_date OR NEW.return_date != OLD.return_date THEN
      IF NOT (
        SELECT bool_and(
          check_item_availability(
            item_id,
            quantity,
            NEW.pickup_date,
            NEW.return_date,
            NEW.id
          )
        )
        FROM order_items
        WHERE order_id = NEW.id
      ) THEN
        RAISE EXCEPTION 'Um ou mais itens não estão disponíveis para o novo período selecionado';
      END IF;

      -- Update availability records
      UPDATE item_availability
      SET
        pickup_date = NEW.pickup_date,
        return_date = NEW.return_date
      WHERE order_id = NEW.id;
    END IF;

    -- If status changed to canceled, delete availability records
    IF NEW.order_status = 'canceled' AND OLD.order_status != 'canceled' THEN
      DELETE FROM item_availability WHERE order_id = NEW.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for managing reservations
CREATE TRIGGER manage_reservations
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION manage_item_reservations();

-- Function to calculate available quantity
CREATE OR REPLACE FUNCTION get_item_available_quantity(
  p_item_id uuid,
  p_date date
)
RETURNS integer AS $$
DECLARE
  total_stock integer;
  reserved integer;
BEGIN
  -- Get total stock
  SELECT current_stock INTO total_stock
  FROM inventory_items
  WHERE id = p_item_id;

  -- Get reserved quantity for the date
  SELECT COALESCE(SUM(quantity), 0) INTO reserved
  FROM item_availability ia
  JOIN orders o ON ia.order_id = o.id
  WHERE ia.item_id = p_item_id
    AND o.order_status NOT IN ('canceled', 'completed')
    AND p_date BETWEEN ia.pickup_date AND ia.return_date;

  RETURN total_stock - reserved;
END;
$$ LANGUAGE plpgsql;