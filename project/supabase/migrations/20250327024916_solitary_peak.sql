/*
  # Add Tasks Management System

  1. New Tables
    - `tasks`
      - Basic task information
      - Priority and status tracking
      - Assignment and ownership
      - Timestamps

  2. Security
    - Enable RLS on tasks table
    - Add policies for authenticated users
*/

-- Create tasks table
CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  due_date date NOT NULL,
  priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
  assigned_to uuid REFERENCES auth.users(id),
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);

-- Enable RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view all tasks"
  ON tasks FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create tasks"
  ON tasks FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update their own tasks or assigned tasks"
  ON tasks FOR UPDATE
  TO authenticated
  USING (auth.uid() IN (created_by, assigned_to))
  WITH CHECK (auth.uid() IN (created_by, assigned_to));

CREATE POLICY "Users can delete their own tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (auth.uid() = created_by);