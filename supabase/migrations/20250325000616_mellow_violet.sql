/*
  # Fix cancel order function

  1. Changes
    - Update cancel_order function to ignore date validation when canceling
    - Add status check to prevent canceling already canceled orders
    - Maintain stock management through existing triggers
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS cancel_order(uuid);

-- Create updated cancel_order function
CREATE OR REPLACE FUNCTION cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status text;
BEGIN
  -- Check if order exists and get current status
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

  -- Update order status to canceled
  UPDATE orders
  SET 
    order_status = 'canceled',
    updated_at = now()
  WHERE id = p_order_id;

  -- Return items to stock is handled by existing triggers

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
END;
$$;