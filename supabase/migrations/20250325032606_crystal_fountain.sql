/*
  # Implement Alerts Dashboard System

  1. New Tables
    - `alert_settings`: User preferences for alert notifications
    - `alert_assignments`: Track alert assignments to team members
    - `alert_history`: Historical record of alerts and actions taken

  2. Changes
    - Add alert priority levels
    - Add alert categories
    - Add alert status tracking
    - Add assignment functionality
*/

-- Create alert_settings table
CREATE TABLE IF NOT EXISTS alert_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL,
  enabled boolean DEFAULT true,
  notify_email boolean DEFAULT true,
  notify_dashboard boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create alert_assignments table
CREATE TABLE IF NOT EXISTS alert_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id uuid REFERENCES inventory_alerts(id) ON DELETE CASCADE,
  assigned_to uuid REFERENCES auth.users(id),
  assigned_by uuid REFERENCES auth.users(id),
  status text DEFAULT 'pending',
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create alert_history table
CREATE TABLE IF NOT EXISTS alert_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id uuid REFERENCES inventory_alerts(id) ON DELETE CASCADE,
  action text NOT NULL,
  performed_by uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Add new columns to inventory_alerts
ALTER TABLE inventory_alerts
ADD COLUMN IF NOT EXISTS priority text DEFAULT 'normal',
ADD COLUMN IF NOT EXISTS acknowledged_at timestamptz,
ADD COLUMN IF NOT EXISTS acknowledged_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES auth.users(id);

-- Enable RLS
ALTER TABLE alert_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_history ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
  ON alert_settings FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Enable write access for authenticated users"
  ON alert_settings FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable read access for authenticated users"
  ON alert_assignments FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Enable write access for authenticated users"
  ON alert_assignments FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated users"
  ON alert_history FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Enable write access for authenticated users"
  ON alert_history FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- Function to create alert history
CREATE OR REPLACE FUNCTION create_alert_history()
RETURNS trigger AS $$
BEGIN
  INSERT INTO alert_history (
    alert_id,
    action,
    performed_by,
    notes
  ) VALUES (
    NEW.id,
    CASE
      WHEN TG_OP = 'INSERT' THEN 'created'
      WHEN NEW.status = 'resolved' AND OLD.status != 'resolved' THEN 'resolved'
      WHEN NEW.acknowledged_at IS NOT NULL AND OLD.acknowledged_at IS NULL THEN 'acknowledged'
      ELSE 'updated'
    END,
    COALESCE(NEW.acknowledged_by, NEW.resolved_by, auth.uid()),
    CASE
      WHEN NEW.status = 'resolved' THEN 'Alert resolved'
      WHEN NEW.acknowledged_at IS NOT NULL AND OLD.acknowledged_at IS NULL THEN 'Alert acknowledged'
      ELSE NULL
    END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for alert history
CREATE TRIGGER create_alert_history_trigger
  AFTER INSERT OR UPDATE ON inventory_alerts
  FOR EACH ROW
  EXECUTE FUNCTION create_alert_history();

-- Function to check alert thresholds
CREATE OR REPLACE FUNCTION check_alert_thresholds()
RETURNS trigger AS $$
BEGIN
  -- Check low stock threshold
  IF NEW.current_stock <= NEW.min_stock THEN
    INSERT INTO inventory_alerts (
      item_id,
      type,
      priority,
      message
    ) VALUES (
      NEW.id,
      'low_stock',
      CASE
        WHEN NEW.current_stock = 0 THEN 'high'
        WHEN NEW.current_stock <= (NEW.min_stock / 2) THEN 'medium'
        ELSE 'low'
      END,
      'Item ' || NEW.name || ' está com estoque baixo (' || 
      NEW.current_stock || ' unidades disponíveis, mínimo: ' || NEW.min_stock || ')'
    ) ON CONFLICT DO NOTHING;
  END IF;

  -- Check utilization rate
  IF EXISTS (
    SELECT 1 FROM inventory_stats
    WHERE item_id = NEW.id
    AND utilization_rate >= 90
    AND date >= CURRENT_DATE
  ) THEN
    INSERT INTO inventory_alerts (
      item_id,
      type,
      priority,
      message
    ) VALUES (
      NEW.id,
      'high_utilization',
      'medium',
      'Item ' || NEW.name || ' está com alta taxa de utilização'
    ) ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for alert thresholds
CREATE TRIGGER check_alert_thresholds_trigger
  AFTER INSERT OR UPDATE ON inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION check_alert_thresholds();