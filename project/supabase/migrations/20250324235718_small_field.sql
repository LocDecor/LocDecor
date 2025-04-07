/*
  # Clean up schema and remove redundant elements

  1. Changes
    - Safely drop unused functions with CASCADE to handle dependencies
    - Clean up duplicate functions
    - Recreate optimized delete_order function

  2. Security
    - Maintain existing RLS policies
    - Keep security settings intact
*/

-- Drop redundant functions safely with CASCADE
DO $$ 
BEGIN
  -- Drop functions if they exist
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_item_availability') THEN
    DROP FUNCTION IF EXISTS get_item_availability(uuid, date, date) CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'can_reserve_item') THEN
    DROP FUNCTION IF EXISTS can_reserve_item(uuid, integer, date, date, uuid) CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_equipment_availability') THEN
    DROP FUNCTION IF EXISTS check_equipment_availability(uuid, integer, date, date) CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'validate_reservation_dates') THEN
    DROP FUNCTION IF EXISTS validate_reservation_dates() CASCADE;
  END IF;

  -- Drop delete_order function if it exists
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_order') THEN
    DROP FUNCTION IF EXISTS delete_order(uuid) CASCADE;
  END IF;
END $$;

-- Recreate optimized delete_order function
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
  WITH deleted_items AS (
    SELECT item_id, quantity
    FROM order_items
    WHERE order_id = p_order_id
  )
  UPDATE inventory_items i
  SET current_stock = i.current_stock + d.quantity
  FROM deleted_items d
  WHERE i.id = d.item_id;

  -- Delete order items
  DELETE FROM order_items
  WHERE order_id = p_order_id;

  -- Delete the order
  DELETE FROM orders
  WHERE id = p_order_id;

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete order: %', SQLERRM;
END;
$$;