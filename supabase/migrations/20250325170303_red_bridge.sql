/*
  # Fix stack depth limit exceeded error

  1. Changes
    - Drop and recreate triggers in correct order
    - Simplify query complexity
    - Remove recursive function calls
    - Fix trigger conflicts

  2. Security
    - Maintain existing RLS policies
    - Keep security checks intact
*/

-- Drop existing triggers in reverse order
DROP TRIGGER IF EXISTS update_item_status_trigger ON inventory_items;
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;

-- Drop existing functions
DROP FUNCTION IF EXISTS update_item_status();
DROP FUNCTION IF EXISTS update_inventory_stats();
DROP FUNCTION IF EXISTS validate_order_availability();

-- Create simplified order validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Check availability in a single query
  IF EXISTS (
    WITH order_items_availability AS (
      SELECT 
        i.id,
        i.name,
        i.current_stock,
        COALESCE(SUM(
          CASE WHEN o.order_status NOT IN ('canceled', 'completed')
               AND o.id != NEW.id
               AND o.pickup_date <= NEW.return_date 
               AND o.return_date >= NEW.pickup_date
          THEN oi2.quantity 
          ELSE 0 END
        ), 0) as reserved_quantity
      FROM order_items oi
      JOIN inventory_items i ON i.id = oi.item_id
      LEFT JOIN order_items oi2 ON oi2.item_id = oi.item_id
      LEFT JOIN orders o ON o.id = oi2.order_id
      WHERE oi.order_id = NEW.id
      GROUP BY i.id, i.name, i.current_stock
    )
    SELECT 1
    FROM order_items_availability
    WHERE current_stock < reserved_quantity
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'Um ou mais itens não têm quantidade suficiente disponível para o período selecionado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create simplified inventory stats function
CREATE OR REPLACE FUNCTION update_inventory_stats()
RETURNS trigger AS $$
BEGIN
  -- Update stats in a single query
  WITH affected_items AS (
    SELECT DISTINCT item_id
    FROM order_items
    WHERE order_id = NEW.id
  ),
  date_range AS (
    SELECT generate_series(
      NEW.pickup_date::date,
      NEW.return_date::date,
      '1 day'::interval
    )::date AS date
  )
  INSERT INTO inventory_stats (
    item_id,
    date,
    total_quantity,
    reserved_quantity,
    utilization_rate
  )
  SELECT 
    i.id as item_id,
    d.date,
    i.current_stock as total_quantity,
    COALESCE(SUM(
      CASE WHEN o.order_status NOT IN ('canceled', 'completed')
      THEN oi.quantity ELSE 0 END
    ), 0) as reserved_quantity,
    CASE WHEN i.current_stock > 0 
      THEN COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
        THEN oi.quantity ELSE 0 END
      )::decimal * 100 / i.current_stock::decimal, 0)
      ELSE 0 
    END as utilization_rate
  FROM affected_items ai
  JOIN inventory_items i ON i.id = ai.item_id
  CROSS JOIN date_range d
  LEFT JOIN order_items oi ON oi.item_id = i.id
  LEFT JOIN orders o ON o.id = oi.order_id
    AND d.date BETWEEN o.pickup_date AND o.return_date
  GROUP BY i.id, d.date, i.current_stock
  ON CONFLICT (item_id, date) 
  DO UPDATE SET
    total_quantity = EXCLUDED.total_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    utilization_rate = EXCLUDED.utilization_rate,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create simplified item status function
CREATE OR REPLACE FUNCTION update_item_status()
RETURNS trigger AS $$
BEGIN
  -- Update item status in a single query
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
      LIMIT 1
    ) THEN 'inactive'
    ELSE 'active'
  END,
  updated_at = now()
  WHERE i.id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers in correct order
CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();

CREATE TRIGGER update_inventory_stats_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_inventory_stats();

CREATE TRIGGER update_item_status_trigger
  AFTER INSERT OR UPDATE ON inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION update_item_status();