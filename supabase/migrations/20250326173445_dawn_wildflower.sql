/*
  # Clean Database Schema

  1. Changes
    - Drop all existing tables and functions
    - Create new optimized schema
    - Implement efficient triggers and functions
    - Fix stack overflow issues

  2. Security
    - Enable RLS on all tables
    - Add proper policies
*/

-- Drop all existing objects
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Create base tables
CREATE TABLE clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  cpf text UNIQUE NOT NULL,
  birth_date date,
  phone text,
  email text,
  address text,
  address_number text,
  neighborhood text,
  zip_code text,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  description text,
  rental_price decimal(10,2) NOT NULL,
  acquisition_price decimal(10,2),
  code text UNIQUE,
  current_stock integer DEFAULT 0,
  min_stock integer DEFAULT 0,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id),
  plan text NOT NULL,
  order_status text DEFAULT 'pending',
  payment_status text DEFAULT 'pending',
  pickup_date date NOT NULL,
  pickup_time time NOT NULL,
  return_date date NOT NULL,
  return_time time NOT NULL,
  total_amount decimal(10,2) NOT NULL,
  payment_method text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  item_id uuid REFERENCES inventory_items(id),
  quantity integer NOT NULL,
  unit_price decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  category text NOT NULL,
  amount decimal(10,2) NOT NULL,
  date date NOT NULL,
  description text,
  payment_method text,
  status text DEFAULT 'completed',
  order_id uuid REFERENCES orders(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE item_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create optimized indexes
CREATE INDEX idx_inventory_items_category ON inventory_items(category);
CREATE INDEX idx_inventory_items_code ON inventory_items(code);
CREATE INDEX idx_inventory_items_name ON inventory_items(name);
CREATE INDEX idx_inventory_items_status ON inventory_items(status);
CREATE INDEX idx_orders_dates ON orders(pickup_date, return_date);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_order_items_item_id ON order_items(item_id);

-- Enable RLS
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_photos ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable full access for authenticated users" ON clients
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable full access for authenticated users" ON inventory_items
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable full access for authenticated users" ON orders
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable full access for authenticated users" ON order_items
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable full access for authenticated users" ON transactions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable full access for authenticated users" ON item_photos
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Create optimized functions
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS trigger AS $$
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Ensure pickup date is not in the past
  IF NEW.pickup_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Data de retirada não pode ser no passado';
  END IF;

  -- Ensure return date is after pickup date
  IF NEW.return_date < NEW.pickup_date THEN
    RAISE EXCEPTION 'Data de devolução deve ser posterior à data de retirada';
  END IF;

  -- If pickup is today, check time
  IF NEW.pickup_date = CURRENT_DATE AND NEW.pickup_time::time < CURRENT_TIME THEN
    RAISE EXCEPTION 'Horário de retirada não pode ser no passado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
DECLARE
  v_item_name text;
  v_available integer;
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Check availability using a materialized calculation
  FOR v_item_name, v_available IN
    WITH order_items_availability AS (
      SELECT 
        i.id,
        i.name,
        i.current_stock,
        COALESCE(SUM(
          CASE WHEN o.order_status NOT IN ('canceled', 'completed')
               AND o.id != NEW.id
               AND o.pickup_date <= NEW.return_date 
               AND o.return_date >= NEW.pickup_date
          THEN oi2.quantity 
          ELSE 0 END
        ), 0) as reserved
      FROM order_items oi
      JOIN inventory_items i ON i.id = oi.item_id
      LEFT JOIN order_items oi2 ON oi2.item_id = oi.item_id
      LEFT JOIN orders o ON o.id = oi2.order_id
      WHERE oi.order_id = NEW.id
      GROUP BY i.id, i.name, i.current_stock
    )
    SELECT 
      name,
      current_stock - reserved as available
    FROM order_items_availability
  LOOP
    IF v_available < 0 THEN
      RAISE EXCEPTION 'Item "%" não tem quantidade suficiente disponível para o período selecionado', v_item_name;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_order_total()
RETURNS trigger AS $$
BEGIN
  UPDATE orders
  SET total_amount = (
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    FROM order_items
    WHERE order_id = NEW.order_id
  )
  WHERE id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION manage_inventory_stock()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE inventory_items
    SET 
      current_stock = current_stock - NEW.quantity,
      status = CASE 
        WHEN current_stock - NEW.quantity <= 0 THEN 'inactive'
        ELSE status 
      END
    WHERE id = NEW.item_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE inventory_items
    SET 
      current_stock = current_stock + OLD.quantity,
      status = CASE 
        WHEN current_stock + OLD.quantity > 0 THEN 'active'
        ELSE status 
      END
    WHERE id = OLD.item_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER validate_order_dates_trigger
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_dates();

CREATE TRIGGER validate_order_availability_trigger
  BEFORE INSERT OR UPDATE OF pickup_date, return_date ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_availability();

CREATE TRIGGER update_order_total_on_items
  AFTER INSERT OR DELETE OR UPDATE ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION update_order_total();

CREATE TRIGGER manage_stock_on_order
  AFTER INSERT OR DELETE ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION manage_inventory_stock();