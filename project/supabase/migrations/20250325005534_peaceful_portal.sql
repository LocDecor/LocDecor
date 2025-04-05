/*
  # Fix cancel order function stack depth issue

  1. Changes
    - Simplify cancel_order function to avoid recursive trigger calls
    - Handle all updates in a single atomic operation
    - Remove unnecessary triggers and cascading updates
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
  v_pickup_date date;
  v_return_date date;
BEGIN
  -- Get order details
  SELECT 
    order_status,
    pickup_date,
    return_date 
  INTO v_order_status, v_pickup_date, v_return_date
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

  -- Perform all updates in a single operation
  WITH order_items_to_cancel AS (
    SELECT 
      oi.item_id,
      oi.quantity
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  )
  UPDATE inventory_items i
  SET 
    current_stock = i.current_stock + c.quantity,
    status = CASE 
      WHEN i.current_stock + c.quantity > 0 THEN 'active'
      ELSE 'inactive'
    END,
    updated_at = now()
  FROM order_items_to_cancel c
  WHERE i.id = c.item_id;

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