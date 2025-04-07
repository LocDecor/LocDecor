/*
  # Fix cancel order function stack depth issue

  1. Changes
    - Simplify cancel order function
    - Remove recursive triggers
    - Fix stack overflow issue

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
BEGIN
  -- Update order status
  UPDATE orders
  SET 
    order_status = 'canceled',
    updated_at = now()
  WHERE id = p_order_id
  AND order_status NOT IN ('canceled', 'completed');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found or cannot be canceled';
  END IF;

  -- Return items to stock in a single operation
  UPDATE inventory_items i
  SET current_stock = i.current_stock + oi.quantity
  FROM order_items oi
  WHERE oi.order_id = p_order_id 
  AND i.id = oi.item_id;

  RETURN;
END;
$$;