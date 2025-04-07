/*
  # Fix order items query stack depth issue

  1. Changes
    - Simplify order items query
    - Remove recursive triggers
    - Fix stack overflow issue

  2. Security
    - Maintain existing permissions
*/

-- Drop existing triggers that might cause recursion
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS generate_inventory_alerts_trigger ON inventory_stats;
DROP TRIGGER IF EXISTS update_item_availability_status_trigger ON order_items;
DROP TRIGGER IF EXISTS handle_order_status_change ON orders;

-- Create simplified function to handle order items
CREATE OR REPLACE FUNCTION get_order_items(p_order_id uuid)
RETURNS TABLE (
  order_id uuid,
  item_id uuid,
  quantity integer,
  unit_price numeric,
  item_name text,
  item_category text,
  item_description text,
  item_rental_price numeric,
  item_current_stock integer,
  item_status text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    oi.order_id,
    oi.item_id,
    oi.quantity,
    oi.unit_price,
    i.name as item_name,
    i.category as item_category,
    i.description as item_description,
    i.rental_price as item_rental_price,
    i.current_stock as item_current_stock,
    i.status as item_status
  FROM order_items oi
  JOIN inventory_items i ON i.id = oi.item_id
  WHERE oi.order_id = p_order_id;
END;
$$ LANGUAGE plpgsql;