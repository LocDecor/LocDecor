/*
  # Inventory Control System Implementation

  1. New Tables
    - `inventory_stats` for tracking usage statistics
    - `inventory_alerts` for real-time monitoring
    - `inventory_reports` for historical data

  2. New Functions
    - Stock management
    - Availability tracking
    - Alert generation
    - Report generation

  3. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create inventory_stats table
CREATE TABLE IF NOT EXISTS inventory_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  date date NOT NULL,
  total_quantity integer NOT NULL,
  reserved_quantity integer DEFAULT 0,
  utilization_rate decimal(5,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(item_id, date)
);

-- Create inventory_alerts table
CREATE TABLE IF NOT EXISTS inventory_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES inventory_items(id) ON DELETE CASCADE,
  type text NOT NULL,
  message text NOT NULL,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

-- Create inventory_reports table
CREATE TABLE IF NOT EXISTS inventory_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  data jsonb NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE inventory_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_reports ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users" ON inventory_stats
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON inventory_stats
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated users" ON inventory_alerts
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON inventory_alerts
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated users" ON inventory_reports
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for authenticated users" ON inventory_reports
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Function to update inventory stats
CREATE OR REPLACE FUNCTION update_inventory_stats()
RETURNS trigger AS $$
BEGIN
  -- Update or insert stats for the affected date range
  WITH date_range AS (
    SELECT generate_series(
      LEAST(OLD.pickup_date, NEW.pickup_date)::date,
      GREATEST(OLD.return_date, NEW.return_date)::date,
      '1 day'::interval
    )::date AS date
  ),
  daily_stats AS (
    SELECT 
      oi.item_id,
      d.date,
      i.current_stock as total_quantity,
      COALESCE(SUM(
        CASE WHEN o.order_status != 'canceled' 
        AND d.date BETWEEN o.pickup_date AND o.return_date
        THEN oi.quantity ELSE 0 END
      ), 0) as reserved_quantity
    FROM date_range d
    CROSS JOIN order_items oi
    JOIN inventory_items i ON i.id = oi.item_id
    LEFT JOIN orders o ON o.id = oi.order_id
    GROUP BY oi.item_id, d.date, i.current_stock
  )
  INSERT INTO inventory_stats (
    item_id,
    date,
    total_quantity,
    reserved_quantity,
    utilization_rate
  )
  SELECT 
    item_id,
    date,
    total_quantity,
    reserved_quantity,
    CASE WHEN total_quantity > 0 
      THEN (reserved_quantity::decimal / total_quantity::decimal * 100)
      ELSE 0 
    END as utilization_rate
  FROM daily_stats
  ON CONFLICT (item_id, date) DO UPDATE
  SET 
    total_quantity = EXCLUDED.total_quantity,
    reserved_quantity = EXCLUDED.reserved_quantity,
    utilization_rate = EXCLUDED.utilization_rate,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for stats update
CREATE TRIGGER update_inventory_stats_trigger
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_inventory_stats();

-- Function to generate inventory alerts
CREATE OR REPLACE FUNCTION generate_inventory_alerts()
RETURNS trigger AS $$
BEGIN
  -- Check for full reservation
  IF NEW.utilization_rate = 100 THEN
    INSERT INTO inventory_alerts (
      item_id,
      type,
      message
    ) VALUES (
      NEW.item_id,
      'full_reservation',
      'Item está 100% reservado para ' || NEW.date
    )
    ON CONFLICT DO NOTHING;
  END IF;

  -- Check for high utilization
  IF NEW.utilization_rate >= 80 AND OLD.utilization_rate < 80 THEN
    INSERT INTO inventory_alerts (
      item_id,
      type,
      message
    ) VALUES (
      NEW.item_id,
      'high_utilization',
      'Item está com ' || NEW.utilization_rate || '% de utilização para ' || NEW.date
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for alert generation
CREATE TRIGGER generate_inventory_alerts_trigger
  AFTER INSERT OR UPDATE ON inventory_stats
  FOR EACH ROW
  EXECUTE FUNCTION generate_inventory_alerts();

-- Function to get item availability forecast
CREATE OR REPLACE FUNCTION get_item_availability_forecast(
  p_item_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS TABLE (
  date date,
  total_quantity integer,
  reserved_quantity integer,
  available_quantity integer,
  utilization_rate decimal(5,2)
) AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE dates AS (
    SELECT p_start_date::date AS date
    UNION ALL
    SELECT date + 1
    FROM dates
    WHERE date < p_end_date
  )
  SELECT 
    d.date,
    i.current_stock as total_quantity,
    COALESCE(s.reserved_quantity, 0) as reserved_quantity,
    i.current_stock - COALESCE(s.reserved_quantity, 0) as available_quantity,
    COALESCE(s.utilization_rate, 0) as utilization_rate
  FROM dates d
  CROSS JOIN inventory_items i
  LEFT JOIN inventory_stats s ON s.item_id = i.id AND s.date = d.date
  WHERE i.id = p_item_id
  ORDER BY d.date;
END;
$$ LANGUAGE plpgsql;

-- Function to get inventory usage report
CREATE OR REPLACE FUNCTION get_inventory_usage_report(
  p_start_date date,
  p_end_date date
)
RETURNS TABLE (
  item_id uuid,
  item_name text,
  avg_utilization decimal(5,2),
  peak_utilization decimal(5,2),
  peak_date date,
  total_reservations bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    i.id as item_id,
    i.name as item_name,
    AVG(s.utilization_rate) as avg_utilization,
    MAX(s.utilization_rate) as peak_utilization,
    (array_agg(s.date ORDER BY s.utilization_rate DESC))[1] as peak_date,
    COUNT(DISTINCT oi.order_id) as total_reservations
  FROM inventory_items i
  LEFT JOIN inventory_stats s ON s.item_id = i.id
  LEFT JOIN order_items oi ON oi.item_id = i.id
  LEFT JOIN orders o ON o.id = oi.order_id
  WHERE s.date BETWEEN p_start_date AND p_end_date
  AND o.order_status != 'canceled'
  GROUP BY i.id, i.name;
END;
$$ LANGUAGE plpgsql;