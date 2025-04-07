/*
  # Fix delete order function with explicit column references

  1. Changes
    - Drop existing function
    - Recreate function with explicit table references
    - Fix ambiguous column references
    - Maintain transaction safety

  2. Security
    - Keep SECURITY DEFINER
    - Maintain existing permissions
*/

-- Drop existing function
DROP FUNCTION IF EXISTS delete_order(uuid);

-- Create the updated function with explicit table references
CREATE OR REPLACE FUNCTION delete_order("order_id" uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete availability records first
  DELETE FROM item_availability
  WHERE item_availability.order_id = delete_order.order_id;

  -- Delete order items and update stock
  WITH deleted_items AS (
    SELECT item_id, quantity
    FROM order_items
    WHERE order_items.order_id = delete_order.order_id
  )
  UPDATE inventory_items i
  SET current_stock = i.current_stock + d.quantity
  FROM deleted_items d
  WHERE i.id = d.item_id;

  -- Delete order items
  DELETE FROM order_items
  WHERE order_items.order_id = delete_order.order_id;

  -- Delete the order
  DELETE FROM orders
  WHERE orders.id = delete_order.order_id;

  -- Return success
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete order: %', SQLERRM;
END;
$$;