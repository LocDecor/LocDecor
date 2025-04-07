/*
  # Fix order validation to skip date checks when completing orders

  1. Changes
    - Update validate_order_dates function to skip validation for completed orders
    - Add status check before date validation
    - Maintain existing validation logic for new orders and updates
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_order_dates_trigger ON orders;
DROP FUNCTION IF EXISTS validate_order_dates();

-- Create improved order validation function
CREATE OR REPLACE FUNCTION validate_order_dates()
RETURNS trigger AS $$
BEGIN
  -- Skip validation when completing an order
  IF TG_OP = 'UPDATE' AND NEW.order_status = 'completed' THEN
    RETURN NEW;
  END IF;

  -- Skip validation for canceled orders
  IF NEW.order_status = 'canceled' THEN
    RETURN NEW;
  END IF;

  -- For new orders or date updates, validate dates
  IF TG_OP = 'INSERT' OR 
     (TG_OP = 'UPDATE' AND 
      (OLD.pickup_date != NEW.pickup_date OR 
       OLD.return_date != NEW.return_date OR 
       OLD.pickup_time != NEW.pickup_time OR 
       OLD.return_time != NEW.return_time)) THEN
    
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER validate_order_dates_trigger
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_dates();