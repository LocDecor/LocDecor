/*
  # Add delete_order function

  1. New Functions
    - `delete_order`: Stored procedure to handle order deletion
      - Deletes order items
      - Updates inventory stock
      - Removes availability records
      - Deletes the order itself

  2. Changes
    - Ensures atomic deletion of orders and related records
    - Properly handles stock updates
    - Maintains data consistency
*/

CREATE OR REPLACE FUNCTION delete_order(order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete availability records first
  DELETE FROM item_availability WHERE order_id = $1;

  -- Delete order items and update stock
  UPDATE inventory_items i
  SET current_stock = i.current_stock + oi.quantity
  FROM order_items oi
  WHERE oi.order_id = $1 AND i.id = oi.item_id;

  -- Delete order items
  DELETE FROM order_items WHERE order_id = $1;

  -- Delete the order
  DELETE FROM orders WHERE id = $1;
END;
$$;