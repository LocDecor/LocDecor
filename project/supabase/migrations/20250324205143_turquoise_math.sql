/*
  # Fix delete order function

  1. Changes
    - Remove explicit transaction handling
    - Simplify function to use implicit transaction
    - Fix parameter naming convention
    - Ensure proper error handling

  2. Security
    - Maintain SECURITY DEFINER
    - Keep existing permissions
*/

-- Drop existing function
DROP FUNCTION IF EXISTS delete_order(uuid);

-- Create the updated function
CREATE OR REPLACE FUNCTION delete_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete availability records first
  DELETE FROM item_availability
  WHERE order_id = p_order_id;

  -- Delete order items and update stock
  UPDATE inventory_items i
  SET current_stock = i.current_stock + oi.quantity
  FROM order_items oi
  WHERE oi.order_id = p_order_id 
  AND i.id = oi.item_id;

  -- Delete order items
  DELETE FROM order_items
  WHERE order_id = p_order_id;

  -- Delete the order
  DELETE FROM orders
  WHERE id = p_order_id;

  -- Return success
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete order: %', SQLERRM;
END;
$$;