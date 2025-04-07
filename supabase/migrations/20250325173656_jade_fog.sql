/*
  # Fix stack depth limit issue

  1. Changes
    - Drop existing triggers and functions
    - Simplify query structure
    - Remove recursive CTEs
    - Optimize join operations
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS validate_order_availability_trigger ON orders;
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS update_item_status_trigger ON inventory_items;

DROP FUNCTION IF EXISTS validate_order_availability();
DROP FUNCTION IF EXISTS update_inventory_stats();
DROP FUNCTION IF EXISTS update_item_status();

-- Create optimized order validation function
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Check availability using a simplified query structure
  IF EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    LEFT JOIN (
      SELECT 
        item_id,
        SUM(quantity) as reserved
      FROM order_items oi2
      JOIN orders o2 ON o2.id = oi2.order_id
      WHERE o2.order_status NOT IN ('canceled', 'completed')
      AND o2.id != NEW.id
      AND o2.pickup_date <= NEW.return_date
      AND o2.return_date >= NEW.pickup_date
      GROUP BY item_id
    ) reservations ON reservations.item_id = oi.item_id
    WHERE oi.order_id = NEW.id
    AND i.current_stock < (oi.quantity + COALESCE(reservations.reserved, 0))
  ) THEN
    RAISE EXCEPTION 'Um ou mais itens não têm quantidade suficiente disponível para o período selecionado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create optimized inventory stats function
CREATE OR REPLACE FUNCTION update_inventory_stats()
RETURNS trigger AS $$
BEGIN
  -- Update stats using a simplified query structure
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
  FROM order_items oi2
  JOIN inventory_items i ON i.id = oi2.item_id
  CROSS JOIN generate_series(
    NEW.pickup_date::date,
    NEW.return_date::date,
    '1 day'::interval
  ) d(date)
  LEFT JOIN order_items oi ON oi.item_id = i.id
  LEFT JOIN orders o ON o.id = oi.order_id
    AND d.date BETWEEN o.pickup_date AND o.return_date
  WHERE oi2.order_id = NEW.id
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

-- Create optimized item status function
CREATE OR REPLACE FUNCTION update_item_status()
RETURNS trigger AS $$
BEGIN
  -- Update item status using a simplified query
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

-- Create triggers
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