/*
  # Reset and rebuild database schema

  1. Changes
    - Drop all existing tables and functions
    - Recreate tables with optimized structure
    - Add proper indexes
    - Implement simplified triggers
    - Remove recursive dependencies

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Drop all existing tables and functions
DROP TABLE IF EXISTS alert_history CASCADE;
DROP TABLE IF EXISTS alert_assignments CASCADE;
DROP TABLE IF EXISTS alert_settings CASCADE;
DROP TABLE IF EXISTS inventory_alerts CASCADE;
DROP TABLE IF EXISTS inventory_reports CASCADE;
DROP TABLE IF EXISTS inventory_stats CASCADE;
DROP TABLE IF EXISTS availability_calendar CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS equipment CASCADE;
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS item_availability CASCADE;
DROP TABLE IF EXISTS item_photos CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory_items CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

-- Create clients table
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

-- Create inventory_items table
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

-- Create orders table
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

-- Create order_items table
CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  item_id uuid REFERENCES inventory_items(id),
  quantity integer NOT NULL,
  unit_price decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create transactions table
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

-- Create item_photos table
CREATE TABLE item_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create indexes
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

-- Create function to validate order dates
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS trigger AS $$
BEGIN
  -- Ensure pickup date is not in the past
  IF NEW.pickup_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Data de retirada não pode ser no passado';
  END IF;

  -- Ensure return date is after pickup date
  IF NEW.return_date < NEW.pickup_date THEN
    RAISE EXCEPTION 'Data de devolução deve ser posterior à data de retirada';
  END IF;

  -- Ensure pickup time is valid if pickup is today
  IF NEW.pickup_date = CURRENT_DATE AND NEW.pickup_time::time < CURRENT_TIME THEN
    RAISE EXCEPTION 'Horário de retirada não pode ser no passado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate order availability
CREATE OR REPLACE FUNCTION validate_order_availability()
RETURNS trigger AS $$
BEGIN
  -- Skip validation for completed or canceled orders
  IF NEW.order_status IN ('completed', 'canceled') THEN
    RETURN NEW;
  END IF;

  -- Check availability in a single query
  IF EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    LEFT JOIN LATERAL (
      SELECT SUM(oi2.quantity) as reserved
      FROM order_items oi2
      JOIN orders o2 ON o2.id = oi2.order_id
      WHERE oi2.item_id = oi.item_id
        AND o2.order_status NOT IN ('canceled', 'completed')
        AND o2.id != NEW.id
        AND o2.pickup_date <= NEW.return_date 
        AND o2.return_date >= NEW.pickup_date
    ) reservations ON true
    WHERE oi.order_id = NEW.id
      AND i.current_stock < (oi.quantity + COALESCE(reservations.reserved, 0))
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'Um ou mais itens não têm quantidade suficiente disponível para o período selecionado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to update order total
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS trigger AS $$
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

-- Create function to manage inventory stock
CREATE OR REPLACE FUNCTION manage_inventory_stock()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE inventory_items
    SET current_stock = current_stock - NEW.quantity
    WHERE id = NEW.item_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE inventory_items
    SET current_stock = current_stock + OLD.quantity
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