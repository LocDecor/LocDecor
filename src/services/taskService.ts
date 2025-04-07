import { supabase } from '../lib/supabase';
import { Task } from '../types/database';
import { startOfDay, endOfWeek, isWithinInterval, addDays } from 'date-fns';

export interface TaskInput {
  title: string;
  description?: string;
  due_date: string;
  priority: 'low' | 'medium' | 'high';
  status: 'pending' | 'in_progress' | 'completed';
}

export interface TaskAlert {
  today: Task[];
  week: Task[];
  overdue: Task[];
}

export const taskService = {
  async createTask(task: TaskInput): Promise<Task> {
    const session = await supabase.auth.getSession();
    if (!session.data.session) {
      throw new Error('User must be authenticated to create tasks');
    }

    const { data, error } = await supabase
      .from('tasks')
      .insert([{
        ...task,
        created_by: session.data.session.user.id,
        assigned_to: session.data.session.user.id
      }])
      .select()
      .single();

    if (error) {
      console.error('Error creating task:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async getTasks(timeframe?: 'today' | 'week' | 'month'): Promise<Task[]> {
    let query = supabase
      .from('tasks')
      .select('*')
      .order('due_date', { ascending: true });

    if (timeframe) {
      const today = new Date();
      const startDate = today.toISOString().split('T')[0];
      
      let endDate = new Date();
      switch (timeframe) {
        case 'today':
          endDate = today;
          break;
        case 'week':
          endDate.setDate(today.getDate() + 7);
          break;
        case 'month':
          endDate.setMonth(today.getMonth() + 1);
          break;
      }

      query = query
        .gte('due_date', startDate)
        .lte('due_date', endDate.toISOString().split('T')[0]);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching tasks:', error);
      throw new Error(error.message);
    }

    return data || [];
  },

  async getTaskAlerts(): Promise<TaskAlert> {
    const today = startOfDay(new Date());
    const weekEnd = endOfWeek(today);

    const { data: tasks, error } = await supabase
      .from('tasks')
      .select('*')
      .not('status', 'eq', 'completed')
      .order('due_date', { ascending: true });

    if (error) {
      console.error('Error fetching task alerts:', error);
      throw new Error(error.message);
    }

    const alerts: TaskAlert = {
      today: [],
      week: [],
      overdue: []
    };

    tasks?.forEach(task => {
      const dueDate = new Date(task.due_date);
      
      if (dueDate < today) {
        alerts.overdue.push(task);
      } else if (isWithinInterval(dueDate, { start: today, end: addDays(today, 1) })) {
        alerts.today.push(task);
      } else if (isWithinInterval(dueDate, { start: today, end: weekEnd })) {
        alerts.week.push(task);
      }
    });

    return alerts;
  },

  async updateTask(id: string, task: Partial<TaskInput>): Promise<Task> {
    const { data, error } = await supabase
      .from('tasks')
      .update({
        ...task,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating task:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async completeTask(id: string): Promise<Task> {
    const { data, error } = await supabase
      .from('tasks')
      .update({
        status: 'completed',
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error completing task:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async deleteTask(id: string): Promise<void> {
    const { error } = await supabase
      .from('tasks')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting task:', error);
      throw new Error(error.message);
    }
  }
};