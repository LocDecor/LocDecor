/*
  # Fix cancel order function stack depth issue

  1. Changes
    - Drop existing function and related triggers
    - Create simplified version without recursive calls
    - Handle all updates in a single atomic operation
    - Remove unnecessary trigger cascades
*/

-- Drop existing function and related triggers
DROP FUNCTION IF EXISTS cancel_order(uuid);
DROP TRIGGER IF EXISTS update_inventory_stats_trigger ON orders;
DROP TRIGGER IF EXISTS generate_inventory_alerts_trigger ON inventory_stats;

-- Create simplified cancel_order function
CREATE OR REPLACE FUNCTION cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status text;
BEGIN
  -- Get order status
  SELECT order_status INTO v_order_status
  FROM orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Check if order can be canceled
  IF v_order_status = 'canceled' THEN
    RAISE EXCEPTION 'Order is already canceled';
  END IF;

  IF v_order_status = 'completed' THEN
    RAISE EXCEPTION 'Cannot cancel completed orders';
  END IF;

  -- Update inventory items stock in a single operation
  UPDATE inventory_items i
  SET 
    current_stock = i.current_stock + oi.quantity,
    status = 'active',
    updated_at = now()
  FROM order_items oi
  WHERE oi.order_id = p_order_id 
  AND i.id = oi.item_id;

  -- Update order status
  UPDATE orders
  SET 
    order_status = 'canceled',
    updated_at = now()
  WHERE id = p_order_id;

  -- Delete availability records
  DELETE FROM item_availability
  WHERE order_id = p_order_id;

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
END;
$$;