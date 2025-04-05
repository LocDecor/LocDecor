import { supabase } from '../lib/supabase';
import { Client } from '../types/database';

export interface ClientInput {
  name: string;
  cpf: string;
  birth_date?: string;
  phone?: string;
  email?: string;
  address?: string;
  address_number?: string;
  neighborhood?: string;
  zip_code?: string;
}

export const clientService = {
  async createClient(client: ClientInput): Promise<Client> {
    const session = await supabase.auth.getSession();
    if (!session.data.session) {
      throw new Error('User must be authenticated to create clients');
    }

    // Validate CPF format
    if (!/^\d{11}$/.test(client.cpf.replace(/\D/g, ''))) {
      throw new Error('CPF inválido');
    }

    const { data, error } = await supabase
      .from('clients')
      .insert([{
        name: client.name,
        cpf: client.cpf.replace(/\D/g, ''),
        birth_date: client.birth_date || null,
        phone: client.phone?.replace(/\D/g, '') || null,
        email: client.email || null,
        address: client.address || null,
        address_number: client.address_number || null,
        neighborhood: client.neighborhood || null,
        zip_code: client.zip_code?.replace(/\D/g, '') || null,
        status: 'active'
      }])
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new Error('CPF já cadastrado');
      }
      console.error('Error creating client:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async updateClient(id: string, client: Partial<ClientInput>): Promise<Client> {
    // Validate CPF format if provided
    if (client.cpf && !/^\d{11}$/.test(client.cpf.replace(/\D/g, ''))) {
      throw new Error('CPF inválido');
    }

    const { data, error } = await supabase
      .from('clients')
      .update({
        name: client.name,
        cpf: client.cpf?.replace(/\D/g, ''),
        birth_date: client.birth_date,
        phone: client.phone?.replace(/\D/g, ''),
        email: client.email,
        address: client.address,
        address_number: client.address_number,
        neighborhood: client.neighborhood,
        zip_code: client.zip_code?.replace(/\D/g, ''),
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        throw new Error('CPF já cadastrado');
      }
      console.error('Error updating client:', error);
      throw new Error(error.message);
    }

    return data;
  },

  async getClients(searchTerm?: string, status?: string): Promise<Client[]> {
    let query = supabase
      .from('clients')
      .select('*')
      .order('name');

    if (searchTerm) {
      query = query.or(`name.ilike.%${searchTerm}%,cpf.ilike.%${searchTerm}%,phone.ilike.%${searchTerm}%`);
    }

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching clients:', error);
      throw new Error(error.message);
    }

    return data || [];
  },

  async deleteClient(id: string): Promise<void> {
    const { error } = await supabase
      .from('clients')
      .update({ status: 'inactive', updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) {
      console.error('Error deleting client:', error);
      throw new Error(error.message);
    }
  }
};