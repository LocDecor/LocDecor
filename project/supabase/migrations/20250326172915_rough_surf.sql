/*
  # Fix Stack Depth Limit Issue

  1. Changes
    - Simplify trigger functions to avoid recursion
    - Optimize query structure to reduce nesting
    - Remove unnecessary function calls
    - Fix stack overflow in inventory management

  2. Security
    - Maintain existing RLS policies
    - Keep existing permissions
*/

-- Drop existing triggers that might cause recursion
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS update_item_status_trigger ON inventory_items;
DROP TRIGGER IF EXISTS update_item_availability_trigger ON orders;

-- Drop existing functions
DROP FUNCTION IF EXISTS validate_order_availability();
DROP FUNCTION IF EXISTS update_inventory_stats();
DROP FUNCTION IF EXISTS update_item_status();
DROP FUNCTION IF EXISTS update_item_availability();

-- Create simplified order validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_item_name text;
  v_available integer;
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Check availability using a materialized calculation
  FOR v_item_name, v_available IN
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
        ), 0) as reserved
      FROM order_items oi
      JOIN inventory_items i ON i.id = oi.item_id
      LEFT JOIN order_items oi2 ON oi2.item_id = oi.item_id
      LEFT JOIN orders o ON o.id = oi2.order_id
      WHERE oi.order_id = NEW.id
      GROUP BY i.id, i.name, i.current_stock
    )
    SELECT 
      name,
      current_stock - reserved as available
    FROM order_items_availability
  LOOP
    IF v_available < 0 THEN
      RAISE EXCEPTION 'Item "%" não tem quantidade suficiente disponível para o período selecionado', v_item_name;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create simplified inventory management function
CREATE OR REPLACE FUNCTION update_item_availability()
RETURNS trigger AS $$
BEGIN
  -- Update availability in a single operation
  WITH date_range AS (
    SELECT generate_series(
      NEW.pickup_date::date,
      NEW.return_date::date,
      '1 day'::interval
    )::date AS date
  ),
  affected_items AS (
    SELECT 
      oi.item_id,
      i.current_stock,
      oi.quantity
    FROM order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    WHERE oi.order_id = NEW.id
  )
  INSERT INTO item_availability (
    item_id,
    date,
    available_quantity,
    reserved_quantity
  )
  SELECT 
    ai.item_id,
    d.date,
    ai.current_stock as available_quantity,
    COALESCE(SUM(
      CASE WHEN o.order_status NOT IN ('canceled', 'completed')
      THEN oi.quantity ELSE 0 END
    ), 0) as reserved_quantity
  FROM affected_items ai
  CROSS JOIN date_range d
  LEFT JOIN order_items oi ON oi.item_id = ai.item_id
  LEFT JOIN orders o ON o.id = oi.order_id
    AND d.date BETWEEN o.pickup_date AND o.return_date
  GROUP BY ai.item_id, d.date, ai.current_stock
  ON CONFLICT (item_id, date) 
  DO UPDATE SET
    available_quantity = EXCLUDED.available_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create simplified item status function
CREATE OR REPLACE FUNCTION update_item_status()
RETURNS trigger AS $$
BEGIN
  -- Update status in a single operation
  UPDATE inventory_items i
  SET 
    status = CASE
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

-- Create triggers with proper ordering
CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();

CREATE TRIGGER update_item_availability_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_item_availability();

CREATE TRIGGER update_item_status_trigger
  AFTER INSERT OR UPDATE ON inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION update_item_status();