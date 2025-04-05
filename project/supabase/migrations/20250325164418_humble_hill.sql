/*
  # Fix stack depth exceeded error

  1. Changes
    - Drop existing recursive triggers
    - Simplify query structure
    - Prevent trigger recursion
    - Fix stack overflow issues

  2. Security
    - Maintain existing RLS policies
    - Keep security settings intact
*/

-- Drop existing triggers that might cause recursion
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS generate_inventory_alerts_trigger ON inventory_stats;
DROP TRIGGER IF EXISTS update_item_availability_status_trigger ON order_items;
DROP TRIGGER IF EXISTS handle_order_status_change ON orders;
DROP TRIGGER IF EXISTS manage_reservations ON orders;
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;

-- Drop existing functions
DROP FUNCTION IF EXISTS update_inventory_stats();
DROP FUNCTION IF EXISTS generate_inventory_alerts();
DROP FUNCTION IF EXISTS update_item_availability_status();
DROP FUNCTION IF EXISTS handle_order_status_change();
DROP FUNCTION IF EXISTS manage_item_reservations();
DROP FUNCTION IF EXISTS validate_order_availability();

-- Create simplified order validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_available integer;
  v_item_name text;
BEGIN
  -- Check each item in a single query
  FOR v_item_name, v_available IN
    SELECT 
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
    GROUP BY i.id, i.name, i.current_stock
  LOOP
    IF v_available < 0 THEN
      RAISE EXCEPTION 'Item "%" não tem quantidade suficiente disponível para o período selecionado', v_item_name;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for order validation
CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();

-- Create simplified function to update inventory stats
CREATE OR REPLACE FUNCTION update_inventory_stats()
RETURNS trigger AS $$
BEGIN
  -- Update stats in a single query
  WITH date_range AS (
    SELECT generate_series(
      LEAST(OLD.pickup_date, NEW.pickup_date)::date,
      GREATEST(OLD.return_date, NEW.return_date)::date,
      '1 day'::interval
    )::date AS date
  ),
  stats AS (
    SELECT 
      oi.item_id,
      d.date,
      i.current_stock as total_quantity,
      COUNT(DISTINCT o.id) as total_orders,
      SUM(oi.quantity) as reserved_quantity
    FROM date_range d
    CROSS JOIN order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND o.order_status NOT IN ('canceled', 'completed')
      AND d.date BETWEEN o.pickup_date AND o.return_date
    GROUP BY oi.item_id, d.date, i.current_stock
  )
  INSERT INTO inventory_stats (
    item_id,
    date,
    total_quantity,
    reserved_quantity,
    utilization_rate
  )
  SELECT 
    item_id,
    date,
    total_quantity,
    COALESCE(reserved_quantity, 0),
    CASE WHEN total_quantity > 0 
      THEN (COALESCE(reserved_quantity, 0)::decimal / total_quantity::decimal * 100)
      ELSE 0 
    END
  FROM stats
  ON CONFLICT (item_id, date) 
  DO UPDATE SET
    total_quantity = EXCLUDED.total_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    utilization_rate = EXCLUDED.utilization_rate,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for stats update
CREATE TRIGGER update_inventory_stats_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_inventory_stats();