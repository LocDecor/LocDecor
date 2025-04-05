/*
  # Fix trigger conflicts and implement inventory management rules

  1. Changes
    - Drop existing triggers before recreation
    - Add proper error handling
    - Implement inventory management rules
    - Fix function dependencies

  2. Rules Implemented
    - Items are active while stock is available
    - Items become inactive when quantity reaches zero
    - Items automatically return to active status
    - Real-time stock updates
*/

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
DROP TRIGGER IF EXISTS update_item_status_trigger ON inventory_items;
DROP TRIGGER IF EXISTS update_item_availability_status_trigger ON order_items;
DROP TRIGGER IF EXISTS handle_order_status_change ON orders;

-- Drop existing functions
DROP FUNCTION IF EXISTS validate_order_availability();
DROP FUNCTION IF EXISTS update_item_status();
DROP FUNCTION IF EXISTS update_item_availability_status();
DROP FUNCTION IF EXISTS handle_order_status_change();
DROP FUNCTION IF EXISTS check_period_availability();

-- Function to check item availability for a period
CREATE OR REPLACE FUNCTION check_period_availability(
  p_item_id uuid,
  p_quantity integer,
  p_pickup_date date,
  p_return_date date,
  p_current_order_id uuid DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
  v_date date := p_pickup_date;
  v_available_quantity integer;
BEGIN
  -- Check availability for each day in the period
  WHILE v_date <= p_return_date LOOP
    -- Calculate available quantity for this date
    SELECT 
      i.current_stock - COALESCE(SUM(
        CASE 
          WHEN o.order_status NOT IN ('canceled', 'completed')
            AND o.id != COALESCE(p_current_order_id, '00000000-0000-0000-0000-000000000000')
          THEN oi.quantity 
          ELSE 0 
        END
      ), 0) INTO v_available_quantity
    FROM inventory_items i
    LEFT JOIN order_items oi ON oi.item_id = p_item_id
    LEFT JOIN orders o ON o.id = oi.order_id
    WHERE i.id = p_item_id
      AND v_date BETWEEN o.pickup_date AND o.return_date;

    -- If not enough quantity available on any day, return false
    IF COALESCE(v_available_quantity, 0) < p_quantity THEN
      RETURN false;
    END IF;

    v_date := v_date + 1;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to validate order dates and availability
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_item_id uuid;
  v_quantity integer;
  v_is_available boolean;
BEGIN
  -- Check each item in the order
  FOR v_item_id, v_quantity IN 
    SELECT oi.item_id, oi.quantity 
    FROM order_items oi 
    WHERE oi.order_id = NEW.id
  LOOP
    -- Check availability for the period
    SELECT check_period_availability(
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

-- Function to update item status based on availability
CREATE OR REPLACE FUNCTION update_item_status()
RETURNS trigger AS $$
DECLARE
  v_available_quantity integer;
BEGIN
  -- Calculate available quantity
  SELECT 
    i.current_stock - COALESCE(SUM(
      CASE WHEN o.order_status NOT IN ('canceled', 'completed')
      THEN oi.quantity ELSE 0 END
    ), 0) INTO v_available_quantity
  FROM inventory_items i
  LEFT JOIN order_items oi ON oi.item_id = NEW.id
  LEFT JOIN orders o ON o.id = oi.order_id
  WHERE i.id = NEW.id
  GROUP BY i.id;

  -- Update item status based on availability
  UPDATE inventory_items
  SET 
    status = CASE
      WHEN COALESCE(v_available_quantity, current_stock) <= 0 THEN 'inactive'
      ELSE 'active'
    END,
    updated_at = now()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle order status changes
CREATE OR REPLACE FUNCTION handle_order_status_change()
RETURNS trigger AS $$
BEGIN
  -- When order is canceled
  IF NEW.order_status = 'canceled' AND OLD.order_status != 'canceled' THEN
    -- Update item availability immediately
    UPDATE inventory_items i
    SET 
      status = CASE
        WHEN i.current_stock > 0 THEN 'active'
        ELSE 'inactive'
      END,
      updated_at = now()
    FROM order_items oi
    WHERE oi.order_id = NEW.id AND i.id = oi.item_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update item availability status
CREATE OR REPLACE FUNCTION update_item_availability_status()
RETURNS trigger AS $$
BEGIN
  -- Update item status based on current availability
  UPDATE inventory_items i
  SET status = CASE
    WHEN i.current_stock <= 0 THEN 'inactive'
    WHEN EXISTS (
      SELECT 1
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      WHERE oi.item_id = i.id
        AND o.order_status NOT IN ('canceled', 'completed')
        AND CURRENT_DATE BETWEEN o.pickup_date AND o.return_date
        AND i.current_stock - oi.quantity <= 0
    ) THEN 'inactive'
    ELSE 'active'
  END,
  updated_at = now()
  WHERE i.id = NEW.item_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();

CREATE TRIGGER update_item_status_trigger
  AFTER INSERT OR UPDATE ON inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION update_item_status();

CREATE TRIGGER update_item_availability_status_trigger
  AFTER INSERT OR UPDATE ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION update_item_availability_status();

CREATE TRIGGER handle_order_status_change
  AFTER UPDATE OF order_status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION handle_order_status_change();