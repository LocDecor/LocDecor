/*
  # Update stock management triggers

  1. Changes
    - Modify stock management trigger to handle order status changes
    - Add trigger for order completion and deletion
    - Update inventory stock based on order status

  2. Functions
    - Update manage_inventory_stock function to handle different scenarios
    - Add checks for order status before updating stock
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS manage_stock_on_order ON order_items;
DROP FUNCTION IF EXISTS manage_inventory_stock();

-- Create updated function to manage inventory stock
CREATE OR REPLACE FUNCTION manage_inventory_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- For new order items, decrease stock
  IF TG_OP = 'INSERT' THEN
    UPDATE inventory_items
    SET current_stock = current_stock - NEW.quantity
    WHERE id = NEW.item_id;
    
  -- For deleted order items, increase stock back
  ELSIF TG_OP = 'DELETE' THEN
    -- Only return items to stock if the order was not completed
    SELECT INTO NEW order_status FROM orders WHERE id = OLD.order_id;
    IF NEW.order_status != 'completed' THEN
      UPDATE inventory_items
      SET current_stock = current_stock + OLD.quantity
      WHERE id = OLD.item_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to handle order status changes
CREATE OR REPLACE FUNCTION handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- When order is completed, items should not return to stock
  IF NEW.order_status = 'completed' AND OLD.order_status != 'completed' THEN
    -- Do nothing with stock as items are considered sold/used
    RETURN NEW;
  -- When order is canceled, return items to stock
  ELSIF NEW.order_status = 'canceled' AND OLD.order_status != 'canceled' THEN
    UPDATE inventory_items i
    SET current_stock = i.current_stock + oi.quantity
    FROM order_items oi
    WHERE oi.order_id = NEW.id AND i.id = oi.item_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER manage_stock_on_order
AFTER INSERT OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION manage_inventory_stock();

CREATE TRIGGER handle_order_status_change
AFTER UPDATE OF order_status ON orders
FOR EACH ROW
EXECUTE FUNCTION handle_order_status_change();