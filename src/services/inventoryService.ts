import { supabase } from '../lib/supabase';
import { InventoryItem } from '../types/database';

export interface InventoryItemInput {
  name: string;
  category: string;
  description?: string;
  rental_price?: number;
  acquisition_price?: number;
  current_stock?: number;
  min_stock?: number;
}

export const inventoryService = {
  async createItem(item: InventoryItemInput): Promise<InventoryItem> {
    const session = await supabase.auth.getSession();
    if (!session.data.session) {
      throw new Error('User must be authenticated to create inventory items');
    }

    // Validate required fields
    if (!item.name || !item.category || !item.rental_price) {
      throw new Error('Nome, categoria e valor de aluguel são obrigatórios');
    }

    // Generate unique code
    const { data: lastItem } = await supabase
      .from('inventory_items')
      .select('code')
      .order('code', { ascending: false })
      .limit(1)
      .single();

    const nextCode = lastItem?.code 
      ? (parseInt(lastItem.code.split('-')[0]) + 1).toString().padStart(5, '0')
      : '00001';
    const code = `${nextCode}-25`;

    const { data, error } = await supabase
      .from('inventory_items')
      .insert([{
        name: item.name,
        category: item.category,
        description: item.description || null,
        rental_price: item.rental_price || 0,
        acquisition_price: item.acquisition_price || null,
        code,
        current_stock: item.current_stock || 0,
        min_stock: item.min_stock || 0,
        status: 'active'
      }])
      .select()
      .single();

    if (error) {
      console.error('Error creating item:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async updateItem(id: string, item: Partial<InventoryItemInput>): Promise<InventoryItem> {
    const { data, error } = await supabase
      .from('inventory_items')
      .update({
        name: item.name,
        category: item.category,
        description: item.description,
        rental_price: item.rental_price || 0,
        acquisition_price: item.acquisition_price || null,
        current_stock: item.current_stock || 0,
        min_stock: item.min_stock || 0,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating item:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async getItems(searchTerm?: string, category?: string): Promise<InventoryItem[]> {
    let query = supabase
      .from('inventory_items')
      .select(`
        *,
        photos:item_photos(*)
      `)
      .order('name');

    if (searchTerm) {
      query = query.or(`name.ilike.%${searchTerm}%,code.ilike.%${searchTerm}%`);
    }

    if (category) {
      query = query.eq('category', category);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching items:', error);
      throw new Error(error.message);
    }

    return data || [];
  },

  async getItemById(id: string): Promise<InventoryItem | null> {
    const { data, error } = await supabase
      .from('inventory_items')
      .select(`
        *,
        photos:item_photos(*)
      `)
      .eq('id', id)
      .single();

    if (error) {
      console.error('Error fetching item:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async deleteItem(id: string): Promise<void> {
    const { error } = await supabase
      .from('inventory_items')
      .update({ status: 'inactive', updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) {
      console.error('Error deleting item:', error);
      throw new Error(error.message);
    }
  }
};