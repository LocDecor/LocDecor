/*
  # Add item availability functions

  1. Functions
    - `check_item_availability`: Checks if an item is available for a specific period
    - `get_item_availability_calendar`: Gets item availability for a date range
    - `validate_order_availability`: Validates availability before order creation/update

  2. Changes
    - Drop existing functions before recreation
    - Add proper error handling
    - Improve availability checks
*/

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS check_item_availability(uuid, integer, date, date, uuid);
DROP FUNCTION IF EXISTS get_item_availability_calendar(uuid, date, date);
DROP FUNCTION IF EXISTS validate_order_availability();

-- Function to check item availability for a specific period
CREATE OR REPLACE FUNCTION check_item_availability(
  p_item_id uuid,
  p_quantity integer,
  p_start_date date,
  p_end_date date,
  p_exclude_order_id uuid DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
  v_available_quantity integer;
  v_total_stock integer;
  v_date date := p_start_date;
BEGIN
  -- Get total stock
  SELECT current_stock INTO v_total_stock
  FROM inventory_items
  WHERE id = p_item_id;

  -- Check availability for each day in the period
  WHILE v_date <= p_end_date LOOP
    -- Calculate reserved quantity for this date
    SELECT v_total_stock - COALESCE(SUM(oi.quantity), 0) INTO v_available_quantity
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE oi.item_id = p_item_id
    AND o.id != COALESCE(p_exclude_order_id, '00000000-0000-0000-0000-000000000000')
    AND o.order_status NOT IN ('canceled', 'completed')
    AND v_date BETWEEN o.pickup_date AND o.return_date;

    -- If not enough quantity available on any day, return false
    IF COALESCE(v_available_quantity, v_total_stock) < p_quantity THEN
      RETURN false;
    END IF;

    v_date := v_date + 1;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to get availability calendar for an item
CREATE OR REPLACE FUNCTION get_item_availability_calendar(
  p_item_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS TABLE (
  date date,
  total_stock integer,
  reserved_quantity integer,
  available_quantity integer
) AS $$
DECLARE
  v_date date := p_start_date;
  v_total_stock integer;
BEGIN
  -- Get total stock
  SELECT current_stock INTO v_total_stock
  FROM inventory_items
  WHERE id = p_item_id;

  -- Generate calendar
  WHILE v_date <= p_end_date LOOP
    -- Calculate reserved quantity for this date
    SELECT 
      v_date as date,
      v_total_stock as total_stock,
      COALESCE(SUM(oi.quantity), 0) as reserved_quantity,
      v_total_stock - COALESCE(SUM(oi.quantity), 0) as available_quantity
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE oi.item_id = p_item_id
    AND o.order_status NOT IN ('canceled', 'completed')
    AND v_date BETWEEN o.pickup_date AND o.return_date
    INTO date, total_stock, reserved_quantity, available_quantity;

    RETURN NEXT;
    v_date := v_date + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to validate availability before order creation/update
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS TRIGGER AS $$
DECLARE
  v_item_id uuid;
  v_quantity integer;
  v_is_available boolean;
BEGIN
  -- Check availability for each item in the order
  FOR v_item_id, v_quantity IN 
    SELECT item_id, quantity 
    FROM order_items 
    WHERE order_id = NEW.id
  LOOP
    SELECT check_item_availability(
      v_item_id,
      v_quantity,
      NEW.pickup_date,
      NEW.return_date,
      CASE WHEN TG_OP = 'UPDATE' THEN NEW.id ELSE NULL END
    ) INTO v_is_available;

    IF NOT v_is_available THEN
      RAISE EXCEPTION 'Item % não está disponível para o período selecionado', v_item_id;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for order validation
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();