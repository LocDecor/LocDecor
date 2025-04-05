/*
  # Dynamic Inventory Management System

  1. New Functions
    - `check_item_availability`: Checks if an item is available for a specific period
    - `get_item_availability_calendar`: Returns daily availability for an item
    - `validate_order_dates`: Validates order dates are valid
    - `update_item_availability`: Updates item availability when orders change

  2. Changes
    - Add validation for order dates
    - Add constraints to prevent invalid dates
    - Add functions to manage item availability
*/

-- Function to validate order dates
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure pickup date is not in the past
  IF NEW.pickup_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Data de retirada não pode ser no passado';
  END IF;

  -- Ensure return date is after pickup date
  IF NEW.return_date < NEW.pickup_date THEN
    RAISE EXCEPTION 'Data de devolução deve ser posterior à data de retirada';
  END IF;

  -- Ensure pickup time is valid if pickup is today
  IF NEW.pickup_date = CURRENT_DATE AND NEW.pickup_time::time < CURRENT_TIME THEN
    RAISE EXCEPTION 'Horário de retirada não pode ser no passado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for date validation
CREATE TRIGGER validate_order_dates_trigger
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_dates();

-- Function to get item availability for a date range
CREATE OR REPLACE FUNCTION get_item_availability(
  p_item_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS TABLE (
  date date,
  available_quantity integer,
  reserved_quantity integer,
  total_quantity integer
) AS $$
DECLARE
  v_total_quantity integer;
BEGIN
  -- Get total quantity
  SELECT current_stock INTO v_total_quantity
  FROM inventory_items
  WHERE id = p_item_id;

  RETURN QUERY
  WITH RECURSIVE dates AS (
    SELECT p_start_date::date AS date
    UNION ALL
    SELECT date + 1
    FROM dates
    WHERE date < p_end_date
  ),
  reservations AS (
    SELECT 
      d.date,
      COALESCE(SUM(oi.quantity), 0) as reserved
    FROM dates d
    LEFT JOIN orders o ON d.date BETWEEN o.pickup_date AND o.return_date
    LEFT JOIN order_items oi ON o.id = oi.order_id AND oi.item_id = p_item_id
    WHERE o.order_status NOT IN ('canceled', 'completed')
    GROUP BY d.date
  )
  SELECT 
    d.date,
    v_total_quantity - COALESCE(r.reserved, 0) as available_quantity,
    COALESCE(r.reserved, 0) as reserved_quantity,
    v_total_quantity as total_quantity
  FROM dates d
  LEFT JOIN reservations r ON d.date = r.date
  ORDER BY d.date;
END;
$$ LANGUAGE plpgsql;

-- Function to check if an item can be reserved
CREATE OR REPLACE FUNCTION can_reserve_item(
  p_item_id uuid,
  p_quantity integer,
  p_start_date date,
  p_end_date date,
  p_exclude_order_id uuid DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
  v_date record;
BEGIN
  FOR v_date IN
    SELECT *
    FROM get_item_availability(p_item_id, p_start_date, p_end_date)
  LOOP
    IF v_date.available_quantity < p_quantity THEN
      RETURN false;
    END IF;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to update item availability status
CREATE OR REPLACE FUNCTION update_item_availability_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Update item status based on current availability
  UPDATE inventory_items
  SET status = CASE
    WHEN current_stock <= min_stock THEN 'low_stock'
    WHEN current_stock = 0 THEN 'out_of_stock'
    ELSE 'active'
  END
  WHERE id = NEW.item_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating item availability status
CREATE TRIGGER update_item_availability_status_trigger
  AFTER INSERT OR UPDATE ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION update_item_availability_status();

-- Add notification table for low stock alerts
CREATE TABLE IF NOT EXISTS inventory_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  type text NOT NULL,
  message text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on notifications
ALTER TABLE inventory_notifications ENABLE ROW LEVEL SECURITY;

-- Create policy for notifications
CREATE POLICY "Enable read access for authenticated users"
  ON inventory_notifications
  FOR SELECT
  TO authenticated
  USING (true);

-- Function to create low stock notifications
CREATE OR REPLACE FUNCTION create_low_stock_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_stock <= NEW.min_stock AND 
     (OLD IS NULL OR OLD.current_stock > OLD.min_stock) THEN
    INSERT INTO inventory_notifications (
      item_id,
      type,
      message
    ) VALUES (
      NEW.id,
      'low_stock',
      'O item ' || NEW.name || ' está com estoque baixo (' || 
      NEW.current_stock || ' unidades disponíveis)'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for low stock notifications
CREATE TRIGGER create_low_stock_notification_trigger
  AFTER INSERT OR UPDATE ON inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION create_low_stock_notification();