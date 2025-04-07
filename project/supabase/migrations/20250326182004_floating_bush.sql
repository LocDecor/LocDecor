-- Drop existing function and trigger
DROP TRIGGER IF EXISTS generate_order_number_trigger ON orders;
DROP FUNCTION IF EXISTS generate_order_number();
DROP FUNCTION IF EXISTS format_order_number(integer);

-- Create improved order number generation function
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS trigger AS $$
DECLARE
  v_number text;
  v_counter integer;
BEGIN
  -- Get the next number from a subquery to avoid sequence issues
  SELECT COALESCE(
    (SELECT REGEXP_REPLACE(order_number, '^PN', '')::integer
     FROM orders
     WHERE order_number ~ '^PN\d{4}$'
     ORDER BY REGEXP_REPLACE(order_number, '^PN', '')::integer DESC
     LIMIT 1), 0) + 1
  INTO v_counter;

  -- Format the order number
  v_number := 'PN' || LPAD(v_counter::text, 4, '0');

  -- Ensure uniqueness
  WHILE EXISTS (SELECT 1 FROM orders WHERE order_number = v_number) LOOP
    v_counter := v_counter + 1;
    v_number := 'PN' || LPAD(v_counter::text, 4, '0');
  END LOOP;

  NEW.order_number := v_number;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new orders
CREATE TRIGGER generate_order_number_trigger
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();