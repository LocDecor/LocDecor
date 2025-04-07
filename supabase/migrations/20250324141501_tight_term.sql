/*
  # Initial Schema Setup

  1. New Tables
    - `clients`
      - Basic client information
      - Contact details
      - Address information
    - `inventory_items`
      - Item details
      - Stock management
      - Pricing information
    - `orders`
      - Order details
      - Rental period
      - Payment information
    - `order_items`
      - Links orders to inventory items
      - Quantity tracking
    - `transactions`
      - Financial transactions
      - Income and expenses tracking

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create clients table
CREATE TABLE IF NOT EXISTS clients (
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
CREATE TABLE IF NOT EXISTS inventory_items (
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
CREATE TABLE IF NOT EXISTS orders (
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
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id),
  item_id uuid REFERENCES inventory_items(id),
  quantity integer NOT NULL,
  unit_price decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
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

-- Enable Row Level Security
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users" ON clients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON clients
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON clients
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable read access for authenticated users" ON inventory_items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON inventory_items
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON inventory_items
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable read access for authenticated users" ON orders
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON orders
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON orders
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable read access for authenticated users" ON order_items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON order_items
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON order_items
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable read access for authenticated users" ON transactions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON transactions
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON transactions
  FOR UPDATE TO authenticated USING (true);