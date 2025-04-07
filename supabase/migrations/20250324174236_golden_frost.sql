/*
  # Add triggers for order management

  1. Changes
    - Add trigger to update inventory stock when order items are added/removed
    - Add trigger to create financial transactions when order status changes
    - Add trigger to update order total amount when items change

  2. Functions
    - Create functions to handle:
      - Stock management
      - Financial transactions
      - Order total calculations
*/

-- Function to manage inventory stock
CREATE OR REPLACE FUNCTION manage_inventory_stock()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Decrease stock when order item is added
    UPDATE inventory_items
    SET current_stock = current_stock - NEW.quantity
    WHERE id = NEW.item_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Increase stock when order item is removed
    UPDATE inventory_items
    SET current_stock = current_stock + OLD.quantity
    WHERE id = OLD.item_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create financial transactions
CREATE OR REPLACE FUNCTION create_order_transaction()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.payment_status = 'completed' AND OLD.payment_status != 'completed' THEN
    INSERT INTO transactions (
      type,
      category,
      amount,
      date,
      description,
      payment_method,
      order_id
    ) VALUES (
      'receita',
      'aluguel',
      NEW.total_amount,
      CURRENT_DATE,
      'Pagamento de pedido #' || NEW.id,
      NEW.payment_method,
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update order total
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE orders
  SET total_amount = (
    SELECT SUM(quantity * unit_price)
    FROM order_items
    WHERE order_id = NEW.order_id
  )
  WHERE id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER manage_stock_on_order
AFTER INSERT OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION manage_inventory_stock();

CREATE TRIGGER create_transaction_on_payment
AFTER UPDATE ON orders
FOR EACH ROW
WHEN (NEW.payment_status = 'completed' AND OLD.payment_status != 'completed')
EXECUTE FUNCTION create_order_transaction();

CREATE TRIGGER update_order_total_on_items
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();