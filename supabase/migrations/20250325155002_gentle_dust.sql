/*
  # Order Status Management System

  1. Changes
    - Add order status history tracking
    - Add status validation
    - Add automatic status updates
    - Remove cron dependency

  2. Security
    - Maintain RLS policies
    - Add proper error handling
*/

-- Create order_status_history table
CREATE TABLE IF NOT EXISTS order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  old_status text,
  new_status text NOT NULL,
  changed_at timestamptz DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id),
  reason text
);

-- Enable RLS
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
  ON order_status_history FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert access for authenticated users"
  ON order_status_history FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Function to validate status transitions
CREATE OR REPLACE FUNCTION validate_order_status_transition()
RETURNS trigger AS $$
BEGIN
  -- Skip validation for the same status
  IF OLD.order_status = NEW.order_status THEN
    RETURN NEW;
  END IF;

  -- Validate status transitions
  IF OLD.order_status = 'canceled' AND NEW.order_status != 'canceled' THEN
    RAISE EXCEPTION 'Cannot change status of canceled orders';
  END IF;

  IF OLD.order_status = 'completed' AND NEW.order_status != 'completed' THEN
    RAISE EXCEPTION 'Cannot change status of completed orders';
  END IF;

  -- Record status change in history
  INSERT INTO order_status_history (
    order_id,
    old_status,
    new_status,
    changed_by,
    reason
  ) VALUES (
    NEW.id,
    OLD.order_status,
    NEW.order_status,
    auth.uid(),
    CASE
      WHEN NEW.order_status = 'active' THEN 'Order pickup confirmed'
      WHEN NEW.order_status = 'completed' THEN 'Order return confirmed'
      WHEN NEW.order_status = 'canceled' THEN 'Order canceled'
      WHEN NEW.order_status = 'delayed' THEN 'Return date passed'
      ELSE NULL
    END
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically update order status
CREATE OR REPLACE FUNCTION update_order_status()
RETURNS trigger AS $$
BEGIN
  -- Update status based on dates and current status
  UPDATE orders
  SET 
    order_status = CASE
      WHEN order_status = 'pending' AND CURRENT_DATE = pickup_date THEN 'ready'
      WHEN order_status IN ('pending', 'ready') AND CURRENT_DATE > pickup_date THEN 'delayed'
      WHEN order_status = 'active' AND CURRENT_DATE > return_date THEN 'delayed'
      ELSE order_status
    END,
    updated_at = now()
  WHERE id = NEW.id
  AND order_status NOT IN ('completed', 'canceled');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER validate_order_status_transition_trigger
  BEFORE UPDATE OF order_status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_status_transition();

CREATE TRIGGER update_order_status_trigger
  AFTER INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_order_status();

-- Function to check for delayed orders
CREATE OR REPLACE FUNCTION check_delayed_orders()
RETURNS void AS $$
BEGIN
  UPDATE orders
  SET 
    order_status = 'delayed',
    updated_at = now()
  WHERE 
    order_status NOT IN ('completed', 'canceled', 'delayed')
    AND (
      (order_status IN ('pending', 'ready') AND CURRENT_DATE > pickup_date)
      OR 
      (order_status = 'active' AND CURRENT_DATE > return_date)
    );
END;
$$ LANGUAGE plpgsql;