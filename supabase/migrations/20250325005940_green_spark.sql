/*
  # Fix cancel order function

  1. Changes
    - Remove complex triggers and stats updates
    - Simplify the function to just handle order cancellation
    - Prevent recursive calls
    - Keep only essential operations

  2. Security
    - Maintain SECURITY DEFINER
    - Keep existing permissions
*/

-- Drop existing function
DROP FUNCTION IF EXISTS cancel_order(uuid);

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

  -- Update order status first
  UPDATE orders
  SET 
    order_status = 'canceled',
    updated_at = now()
  WHERE id = p_order_id;

  -- Return items to stock
  UPDATE inventory_items i
  SET current_stock = i.current_stock + oi.quantity
  FROM order_items oi
  WHERE oi.order_id = p_order_id 
  AND i.id = oi.item_id;

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
END;
$$;