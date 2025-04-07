-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS validate_order_dates_trigger ON orders;
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
DROP FUNCTION IF EXISTS validate_order_dates();
DROP FUNCTION IF EXISTS validate_order_availability();

-- Create simplified order validation function
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS trigger AS $$
BEGIN
  -- Ensure pickup date is not in the past
  IF NEW.pickup_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Data de retirada não pode ser no passado';
  END IF;

  -- Ensure return date is after pickup date
  IF NEW.return_date < NEW.pickup_date THEN
    RAISE EXCEPTION 'Data de devolução deve ser posterior à data de retirada';
  END IF;

  -- If pickup is today, check time
  IF NEW.pickup_date = CURRENT_DATE AND NEW.pickup_time::time < CURRENT_TIME THEN
    RAISE EXCEPTION 'Horário de retirada não pode ser no passado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create optimized availability validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_item RECORD;
  v_available integer;
BEGIN
  -- Check each item in a single query
  FOR v_item IN
    SELECT 
      oi.item_id,
      oi.quantity,
      i.name,
      i.current_stock - COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
             AND o.id != NEW.id
             AND o.pickup_date <= NEW.return_date 
             AND o.return_date >= NEW.pickup_date
        THEN oi2.quantity 
        ELSE 0 END
      ), 0) as available
    FROM order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    LEFT JOIN order_items oi2 ON oi2.item_id = oi.item_id
    LEFT JOIN orders o ON o.id = oi2.order_id
    WHERE oi.order_id = NEW.id
    GROUP BY oi.item_id, oi.quantity, i.name, i.current_stock
  LOOP
    IF v_item.available < v_item.quantity THEN
      RAISE EXCEPTION 'Item "%" não tem quantidade suficiente disponível para o período selecionado', v_item.name;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers with proper ordering
CREATE TRIGGER validate_order_dates_trigger
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_dates();

CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();