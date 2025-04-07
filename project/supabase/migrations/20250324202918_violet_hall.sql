/*
  # Fix order_id ambiguity in SQL functions

  1. Changes
    - Update SQL functions to use explicit table references
    - Fix ambiguous column references
    - Improve error handling in functions

  2. Security
    - Maintain existing RLS policies
    - Keep security definer settings
*/

-- Update the check_item_availability function
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
  SELECT COALESCE(SUM(ia.quantity), 0) INTO total_reserved
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

-- Update the manage_item_reservations function
CREATE OR REPLACE FUNCTION manage_item_reservations()
RETURNS TRIGGER AS $$
BEGIN
  -- For new orders
  IF TG_OP = 'INSERT' THEN
    -- Check availability for each item
    IF NOT (
      SELECT bool_and(
        check_item_availability(
          oi.item_id,
          oi.quantity,
          NEW.pickup_date,
          NEW.return_date
        )
      )
      FROM order_items oi
      WHERE oi.order_id = NEW.id
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
      oi.item_id,
      NEW.id,
      oi.quantity,
      NEW.pickup_date,
      NEW.return_date
    FROM order_items oi
    WHERE oi.order_id = NEW.id;

  -- For updates
  ELSIF TG_OP = 'UPDATE' THEN
    -- If dates changed, check availability
    IF NEW.pickup_date != OLD.pickup_date OR NEW.return_date != OLD.return_date THEN
      IF NOT (
        SELECT bool_and(
          check_item_availability(
            oi.item_id,
            oi.quantity,
            NEW.pickup_date,
            NEW.return_date,
            NEW.id
          )
        )
        FROM order_items oi
        WHERE oi.order_id = NEW.id
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

-- Update the get_item_available_quantity function
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
  SELECT COALESCE(SUM(ia.quantity), 0) INTO reserved
  FROM item_availability ia
  JOIN orders o ON ia.order_id = o.id
  WHERE ia.item_id = p_item_id
    AND o.order_status NOT IN ('canceled', 'completed')
    AND p_date BETWEEN ia.pickup_date AND ia.return_date;

  RETURN total_stock - reserved;
END;
$$ LANGUAGE plpgsql;