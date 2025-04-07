/*
  # Rental System Schema Setup

  1. New Tables
    - `equipment`
      - Basic equipment information
      - Stock management
      - Pricing information
    - `reservations`
      - Reservation details
      - Date ranges
      - Equipment quantities
    - `availability_calendar`
      - Daily availability tracking
      - Reserved quantities
      - Available quantities

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create equipment table
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  category text NOT NULL,
  daily_rate decimal(10,2) NOT NULL,
  total_quantity integer NOT NULL,
  min_quantity integer DEFAULT 1,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create reservations table
CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id),
  quantity integer NOT NULL,
  pickup_date date NOT NULL,
  return_date date NOT NULL,
  status text DEFAULT 'pending',
  customer_name text NOT NULL,
  customer_phone text,
  customer_email text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create availability_calendar table
CREATE TABLE IF NOT EXISTS availability_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id),
  date date NOT NULL,
  reserved_quantity integer DEFAULT 0,
  available_quantity integer,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(equipment_id, date)
);

-- Enable Row Level Security
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability_calendar ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users" ON equipment
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON equipment
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated users" ON reservations
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON reservations
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated users" ON availability_calendar
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON availability_calendar
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Create function to update availability calendar
CREATE OR REPLACE FUNCTION update_availability_calendar()
RETURNS TRIGGER AS $$
DECLARE
  v_date date;
BEGIN
  -- For new reservations
  IF TG_OP = 'INSERT' THEN
    v_date := NEW.pickup_date;
    WHILE v_date <= NEW.return_date LOOP
      -- Insert or update availability calendar
      INSERT INTO availability_calendar (
        equipment_id,
        date,
        reserved_quantity,
        available_quantity
      )
      VALUES (
        NEW.equipment_id,
        v_date,
        NEW.quantity,
        (SELECT total_quantity FROM equipment WHERE id = NEW.equipment_id) - NEW.quantity
      )
      ON CONFLICT (equipment_id, date) DO UPDATE
      SET
        reserved_quantity = availability_calendar.reserved_quantity + NEW.quantity,
        available_quantity = (SELECT total_quantity FROM equipment WHERE id = NEW.equipment_id) - (availability_calendar.reserved_quantity + NEW.quantity),
        updated_at = now();
      
      v_date := v_date + 1;
    END LOOP;
  END IF;

  -- For canceled reservations
  IF TG_OP = 'UPDATE' AND NEW.status = 'canceled' AND OLD.status != 'canceled' THEN
    v_date := NEW.pickup_date;
    WHILE v_date <= NEW.return_date LOOP
      UPDATE availability_calendar
      SET
        reserved_quantity = reserved_quantity - NEW.quantity,
        available_quantity = available_quantity + NEW.quantity,
        updated_at = now()
      WHERE equipment_id = NEW.equipment_id AND date = v_date;
      
      v_date := v_date + 1;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating availability calendar
CREATE TRIGGER update_availability_calendar_trigger
  AFTER INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_availability_calendar();

-- Create function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_quantity integer,
  p_pickup_date date,
  p_return_date date
)
RETURNS boolean AS $$
DECLARE
  v_date date;
  v_available integer;
BEGIN
  v_date := p_pickup_date;
  WHILE v_date <= p_return_date LOOP
    SELECT available_quantity INTO v_available
    FROM availability_calendar
    WHERE equipment_id = p_equipment_id AND date = v_date;

    IF v_available IS NULL THEN
      -- If no entry exists, check total quantity
      SELECT total_quantity INTO v_available
      FROM equipment
      WHERE id = p_equipment_id;
    END IF;

    IF v_available < p_quantity THEN
      RETURN false;
    END IF;

    v_date := v_date + 1;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate reservation dates
CREATE OR REPLACE FUNCTION validate_reservation_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if dates are valid
  IF NEW.pickup_date > NEW.return_date THEN
    RAISE EXCEPTION 'Pickup date must be before or equal to return date';
  END IF;

  -- Check if dates are in the past
  IF NEW.pickup_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Cannot create reservations in the past';
  END IF;

  -- Check availability
  IF NOT check_equipment_availability(NEW.equipment_id, NEW.quantity, NEW.pickup_date, NEW.return_date) THEN
    RAISE EXCEPTION 'Equipment is not available for the selected dates';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for validating reservation dates
CREATE TRIGGER validate_reservation_dates_trigger
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation_dates();