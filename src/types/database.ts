import { User } from '@supabase/supabase-js';

export interface Client {
  id: string;
  name: string;
  cpf: string;
  birth_date?: string;
  phone?: string;
  email?: string;
  address?: string;
  address_number?: string;
  neighborhood?: string;
  zip_code?: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface InventoryItem {
  id: string;
  name: string;
  category: string;
  description?: string;
  rental_price: number;
  acquisition_price?: number;
  code?: string;
  current_stock: number;
  min_stock: number;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface Order {
  id: string;
  client_id: string;
  client?: Client;
  plan: string;
  order_status: string;
  payment_status: string;
  pickup_date: string;
  pickup_time: string;
  return_date: string;
  return_time: string;
  total_amount: number;
  payment_method?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
  order_number: string;
  items?: OrderItem[];
}

export interface OrderItem {
  id: string;
  order_id: string;
  item_id: string;
  item?: InventoryItem;
  quantity: number;
  unit_price: number;
  created_at: string;
}

export interface Transaction {
  id: string;
  type: string;
  category: string;
  amount: number;
  date: string;
  description?: string;
  payment_method?: string;
  status: string;
  order_id?: string;
  created_at: string;
}

export interface Task {
  id: string;
  title: string;
  description?: string;
  due_date: string;
  priority: 'low' | 'medium' | 'high';
  status: 'pending' | 'in_progress' | 'completed';
  assigned_to?: User['id'];
  created_by: User['id'];
  created_at: string;
  updated_at: string;
}

export interface UpcomingPickup extends Order {
  client: Client;
  items: Array<{
    quantity: number;
    unit_price: number;
    item: {
      name: string;
      category: string;
    };
  }>;
}

export interface DashboardMetrics {
  totalOrders: number;
  completedOrders: number;
  canceledOrders: number;
  revenue: number;
  expenses: number;
  balance: number;
  occupationRate: number;
  returningCustomers: number;
  monthlyGrowth: number;
}

export interface ChartData {
  date: string;
  value: number;
  previousValue?: number;
}