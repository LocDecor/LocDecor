/*
  # Fix cancel order function stack depth issue

  1. Changes
    - Optimize cancel_order function to avoid recursive trigger calls
    - Handle all updates in a single atomic operation
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

  -- Perform all updates in a single transaction
  BEGIN
    -- Update order status
    UPDATE orders
    SET 
      order_status = 'canceled',
      updated_at = now()
    WHERE id = p_order_id;

    -- Return items to stock
    UPDATE inventory_items i
    SET 
      current_stock = i.current_stock + oi.quantity,
      status = 'active',
      updated_at = now()
    FROM order_items oi
    WHERE oi.order_id = p_order_id 
    AND i.id = oi.item_id;

    -- Delete availability records
    DELETE FROM item_availability
    WHERE order_id = p_order_id;

    -- Update inventory stats directly
    WITH affected_items AS (
      SELECT DISTINCT oi.item_id
      FROM order_items oi
      WHERE oi.order_id = p_order_id
    )
    INSERT INTO inventory_stats (
      item_id,
      date,
      total_quantity,
      reserved_quantity,
      utilization_rate
    )
    SELECT 
      i.id as item_id,
      d.date,
      i.current_stock as total_quantity,
      COALESCE(
        (SELECT SUM(oi.quantity)
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         WHERE oi.item_id = i.id
         AND o.id != p_order_id
         AND o.order_status NOT IN ('canceled', 'completed')
         AND d.date BETWEEN o.pickup_date AND o.return_date
        ), 0
      ) as reserved_quantity,
      CASE 
        WHEN i.current_stock > 0 THEN
          COALESCE(
            (SELECT SUM(oi.quantity)::decimal * 100 / i.current_stock::decimal
             FROM order_items oi
             JOIN orders o ON o.id = oi.order_id
             WHERE oi.item_id = i.id
             AND o.id != p_order_id
             AND o.order_status NOT IN ('canceled', 'completed')
             AND d.date BETWEEN o.pickup_date AND o.return_date
            ), 0
          )
        ELSE 0
      END as utilization_rate
    FROM affected_items ai
    JOIN inventory_items i ON i.id = ai.item_id
    CROSS JOIN generate_series(
      v_pickup_date,
      v_return_date,
      '1 day'::interval
    ) AS d(date)
    ON CONFLICT (item_id, date) 
    DO UPDATE SET
      total_quantity = EXCLUDED.total_quantity,
      reserved_quantity = EXCLUDED.reserved_quantity,
      utilization_rate = EXCLUDED.utilization_rate,
      updated_at = now();

  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Failed to cancel order: %', SQLERRM;
  END;
END;
$$;