/*
  # Fix ambiguous order_id reference in delete_order function

  1. Changes
    - Update delete_order function to use explicit table references
    - Fix ambiguous column references
    - Improve error handling
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS delete_order(uuid);

-- Create the updated function with explicit table references
CREATE OR REPLACE FUNCTION delete_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete availability records first
  DELETE FROM item_availability
  WHERE item_availability.order_id = p_order_id;

  -- Delete order items and update stock
  UPDATE inventory_items i
  SET current_stock = i.current_stock + oi.quantity
  FROM order_items oi
  WHERE oi.order_id = p_order_id 
  AND i.id = oi.item_id;

  -- Delete order items
  DELETE FROM order_items
  WHERE order_items.order_id = p_order_id;

  -- Delete the order
  DELETE FROM orders
  WHERE orders.id = p_order_id;

  -- If we get here, everything succeeded
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    -- Re-raise the error with a more specific message
    RAISE EXCEPTION 'Failed to delete order: %', SQLERRM;
END;
$$;