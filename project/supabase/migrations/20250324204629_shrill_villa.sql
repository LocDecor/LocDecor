/*
  # Fix delete_order function

  1. Changes
    - Drop existing function
    - Recreate with proper parameter name
    - Add better error handling
    - Add transaction support
*/

-- Drop existing function
DROP FUNCTION IF EXISTS delete_order(uuid);

-- Create the updated function
CREATE OR REPLACE FUNCTION delete_order(order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Start transaction
  BEGIN
    -- Delete availability records first
    DELETE FROM item_availability
    WHERE item_availability.order_id = order_id;

    -- Delete order items and update stock
    UPDATE inventory_items i
    SET current_stock = i.current_stock + oi.quantity
    FROM order_items oi
    WHERE oi.order_id = order_id 
    AND i.id = oi.item_id;

    -- Delete order items
    DELETE FROM order_items
    WHERE order_items.order_id = order_id;

    -- Delete the order
    DELETE FROM orders
    WHERE orders.id = order_id;

    -- Commit transaction
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback on error
      ROLLBACK;
      RAISE EXCEPTION 'Failed to delete order: %', SQLERRM;
  END;
END;
$$;