-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS validate_order_dates_trigger ON orders;
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
DROP FUNCTION IF EXISTS validate_order_dates();
DROP FUNCTION IF EXISTS validate_order_availability();

-- Create improved order validation function
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS trigger AS $$
BEGIN
  -- Ensure pickup date is not in the past
  IF NEW.pickup_date < CURRENT_DATE OR 
     (NEW.pickup_date = CURRENT_DATE AND NEW.pickup_time::time < CURRENT_TIME) THEN
    RAISE EXCEPTION 'Data e hora de retirada não podem estar no passado';
  END IF;

  -- Ensure return date is after pickup date
  IF NEW.return_date < NEW.pickup_date OR 
     (NEW.return_date = NEW.pickup_date AND NEW.return_time::time <= NEW.pickup_time::time) THEN
    RAISE EXCEPTION 'Data e hora de devolução devem ser posteriores à data e hora de retirada';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create improved availability validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_item_id uuid;
  v_quantity integer;
  v_available_quantity integer;
  v_item_name text;
BEGIN
  -- Check availability for each item in the order
  FOR v_item_id, v_quantity IN 
    SELECT item_id, quantity 
    FROM order_items 
    WHERE order_id = NEW.id
  LOOP
    -- Get item name for error message
    SELECT name INTO v_item_name
    FROM inventory_items
    WHERE id = v_item_id;

    -- Calculate available quantity for the period
    SELECT 
      i.current_stock - COALESCE(SUM(
        CASE 
          WHEN o.order_status NOT IN ('canceled', 'completed')
            AND o.id != NEW.id
          THEN oi.quantity 
          ELSE 0 
        END
      ), 0) INTO v_available_quantity
    FROM inventory_items i
    LEFT JOIN order_items oi ON oi.item_id = v_item_id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND daterange(o.pickup_date, o.return_date, '[]') && 
          daterange(NEW.pickup_date, NEW.return_date, '[]')
    WHERE i.id = v_item_id
    GROUP BY i.current_stock;

    -- Check if enough quantity is available
    IF COALESCE(v_available_quantity, 0) < v_quantity THEN
      RAISE EXCEPTION 'Item "%" não tem quantidade suficiente disponível para o período selecionado', v_item_name;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER validate_order_dates_trigger
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_dates();

CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();