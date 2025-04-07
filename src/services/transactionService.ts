import { supabase } from '../lib/supabase';
import { Transaction } from '../types/database';

export interface TransactionInput {
  type: 'receita' | 'despesa';
  category: string;
  amount: number;
  date: string;
  description?: string;
  payment_method?: string;
  status?: string;
  order_id?: string;
}

export const transactionService = {
  async createTransaction(transaction: TransactionInput): Promise<Transaction> {
    const session = await supabase.auth.getSession();
    if (!session.data.session) {
      throw new Error('User must be authenticated to create transactions');
    }

    const { data, error } = await supabase
      .from('transactions')
      .insert([{
        type: transaction.type,
        category: transaction.category,
        amount: transaction.amount,
        date: transaction.date,
        description: transaction.description,
        payment_method: transaction.payment_method,
        status: transaction.status || 'completed',
        order_id: transaction.order_id
      }])
      .select()
      .single();

    if (error) {
      console.error('Error creating transaction:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async getTransactions(searchTerm?: string, type?: string): Promise<Transaction[]> {
    let query = supabase
      .from('transactions')
      .select('*')
      .order('date', { ascending: false });

    if (searchTerm) {
      query = query.or(`description.ilike.%${searchTerm}%,category.ilike.%${searchTerm}%`);
    }

    if (type) {
      query = query.eq('type', type);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching transactions:', error);
      throw new Error(error.message);
    }

    return data || [];
  },

  async updateTransaction(id: string, transaction: Partial<TransactionInput>): Promise<Transaction> {
    const { data, error } = await supabase
      .from('transactions')
      .update({
        type: transaction.type,
        category: transaction.category,
        amount: transaction.amount,
        date: transaction.date,
        description: transaction.description,
        payment_method: transaction.payment_method,
        status: transaction.status,
        order_id: transaction.order_id
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating transaction:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async deleteTransaction(id: string): Promise<void> {
    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting transaction:', error);
      throw new Error(error.message);
    }
  }
};