/*
  # Fix cancel order function stack depth issue

  1. Changes
    - Optimize cancel_order function to avoid recursive trigger calls
    - Handle stock updates directly in the function
    - Prevent trigger recursion
    - Add proper error handling
*/

-- Drop existing function
DROP FUNCTION IF EXISTS cancel_order(uuid);

-- Create optimized cancel_order function
CREATE OR REPLACE FUNCTION cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status text;
  v_order_items RECORD;
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

  -- Begin atomic operation
  BEGIN
    -- Update order status first
    UPDATE orders
    SET 
      order_status = 'canceled',
      updated_at = now()
    WHERE id = p_order_id;

    -- Return items to stock and update their status
    FOR v_order_items IN 
      SELECT oi.item_id, oi.quantity, i.current_stock
      FROM order_items oi
      JOIN inventory_items i ON i.id = oi.item_id
      WHERE oi.order_id = p_order_id
    LOOP
      -- Update inventory item stock and status
      UPDATE inventory_items
      SET 
        current_stock = current_stock + v_order_items.quantity,
        status = CASE 
          WHEN current_stock + v_order_items.quantity > 0 THEN 'active'
          ELSE 'inactive'
        END,
        updated_at = now()
      WHERE id = v_order_items.item_id;
    END LOOP;

    -- Delete availability records
    DELETE FROM item_availability
    WHERE order_id = p_order_id;

    -- Update inventory stats
    INSERT INTO inventory_stats (
      item_id,
      date,
      total_quantity,
      reserved_quantity,
      utilization_rate
    )
    SELECT 
      oi.item_id,
      d.date,
      i.current_stock + oi.quantity,
      COALESCE(
        (SELECT SUM(oi2.quantity)
         FROM order_items oi2
         JOIN orders o2 ON o2.id = oi2.order_id
         WHERE oi2.item_id = oi.item_id
         AND o2.id != p_order_id
         AND o2.order_status NOT IN ('canceled', 'completed')
         AND d.date BETWEEN o2.pickup_date AND o2.return_date
        ), 0
      ),
      CASE 
        WHEN i.current_stock + oi.quantity > 0 THEN
          COALESCE(
            (SELECT SUM(oi2.quantity)::decimal * 100 / (i.current_stock + oi.quantity)::decimal
             FROM order_items oi2
             JOIN orders o2 ON o2.id = oi2.order_id
             WHERE oi2.item_id = oi.item_id
             AND o2.id != p_order_id
             AND o2.order_status NOT IN ('canceled', 'completed')
             AND d.date BETWEEN o2.pickup_date AND o2.return_date
            ), 0
          )
        ELSE 0
      END
    FROM order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    CROSS JOIN generate_series(
      (SELECT pickup_date FROM orders WHERE id = p_order_id),
      (SELECT return_date FROM orders WHERE id = p_order_id),
      '1 day'::interval
    ) AS d(date)
    WHERE oi.order_id = p_order_id
    ON CONFLICT (item_id, date) 
    DO UPDATE SET
      total_quantity = EXCLUDED.total_quantity,
      reserved_quantity = EXCLUDED.reserved_quantity,
      utilization_rate = EXCLUDED.utilization_rate,
      updated_at = now();
  END;

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
END;
$$;