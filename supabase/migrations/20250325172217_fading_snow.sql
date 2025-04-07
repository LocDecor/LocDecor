/*
  # Fix function parameters and optimize queries

  1. Changes
    - Drop existing functions before recreation
    - Add proper parameter names
    - Add indexes for performance
    - Optimize query structure
*/

-- Drop existing functions first
DROP FUNCTION IF EXISTS check_item_availability(uuid, integer, date, date, uuid);
DROP FUNCTION IF EXISTS calculate_inventory_stats(date, date, uuid[]);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_inventory_items_status ON inventory_items(status);
CREATE INDEX IF NOT EXISTS idx_inventory_items_category ON inventory_items(category);
CREATE INDEX IF NOT EXISTS idx_inventory_items_name ON inventory_items(name);
CREATE INDEX IF NOT EXISTS idx_inventory_items_code ON inventory_items(code);
CREATE INDEX IF NOT EXISTS idx_order_items_item_id ON order_items(item_id);
CREATE INDEX IF NOT EXISTS idx_orders_dates ON orders(pickup_date, return_date);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status);

-- Create optimized availability check function
CREATE OR REPLACE FUNCTION check_item_availability(
  in_item_id uuid,
  in_quantity integer,
  in_pickup_date date,
  in_return_date date,
  in_current_order_id uuid DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
  RETURN NOT EXISTS (
    WITH date_range AS (
      SELECT d::date
      FROM generate_series(in_pickup_date, in_return_date, '1 day'::interval) d
    ),
    daily_reservations AS (
      SELECT 
        d.d as date,
        COALESCE(SUM(
          CASE WHEN o.order_status NOT IN ('canceled', 'completed')
               AND o.id != COALESCE(in_current_order_id, '00000000-0000-0000-0000-000000000000')
          THEN oi.quantity 
          ELSE 0 END
        ), 0) as reserved
      FROM date_range d
      LEFT JOIN orders o ON d.d BETWEEN o.pickup_date AND o.return_date
      LEFT JOIN order_items oi ON oi.order_id = o.id AND oi.item_id = in_item_id
      GROUP BY d.d
    )
    SELECT 1
    FROM inventory_items i
    CROSS JOIN daily_reservations r
    WHERE i.id = in_item_id
    AND i.current_stock - r.reserved < in_quantity
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

-- Create optimized inventory stats function
CREATE OR REPLACE FUNCTION calculate_inventory_stats(
  in_start_date date,
  in_end_date date,
  in_item_ids uuid[] DEFAULT NULL
)
RETURNS TABLE (
  item_id uuid,
  date date,
  total_quantity integer,
  reserved_quantity integer,
  utilization_rate numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE dates AS (
    SELECT in_start_date::date as date
    UNION ALL
    SELECT date + 1
    FROM dates
    WHERE date < in_end_date
  ),
  base_data AS (
    SELECT 
      i.id as item_id,
      d.date,
      i.current_stock as total_quantity,
      COALESCE(SUM(
        CASE WHEN o.order_status NOT IN ('canceled', 'completed')
        THEN oi.quantity ELSE 0 END
      ), 0) as reserved_quantity
    FROM dates d
    CROSS JOIN inventory_items i
    LEFT JOIN order_items oi ON oi.item_id = i.id
    LEFT JOIN orders o ON o.id = oi.order_id
      AND d.date BETWEEN o.pickup_date AND o.return_date
    WHERE in_item_ids IS NULL OR i.id = ANY(in_item_ids)
    GROUP BY i.id, d.date, i.current_stock
  )
  SELECT 
    item_id,
    date,
    total_quantity,
    reserved_quantity,
    CASE WHEN total_quantity > 0 
      THEN (reserved_quantity::numeric * 100 / total_quantity::numeric)
      ELSE 0 
    END as utilization_rate
  FROM base_data;
END;
$$ LANGUAGE plpgsql;