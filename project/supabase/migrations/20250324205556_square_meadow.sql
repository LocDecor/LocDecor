/*
  # Add cancel order function

  1. Changes
    - Add function to cancel orders
    - Automatically returns items to stock through existing triggers
    - Maintains order history
    - Updates order status to 'canceled'

  2. Security
    - SECURITY DEFINER to ensure consistent permissions
    - Proper error handling
*/

CREATE OR REPLACE FUNCTION cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update order status to canceled
  UPDATE orders
  SET 
    order_status = 'canceled',
    updated_at = now()
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Return success
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
END;
$$;