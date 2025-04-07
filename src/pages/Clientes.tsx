import React, { useState, FormEvent, useEffect } from 'react';
import { Search, Plus, Phone, Mail, MapPin, Loader2, Pencil } from 'lucide-react';
import { clientService, ClientInput } from '../services/clientService';
import { Client } from '../types/database';

const Clientes = () => {
  const [formData, setFormData] = useState<ClientInput>({
    name: '',
    cpf: '',
    birth_date: '',
    phone: '',
    email: '',
    address: '',
    address_number: '',
    neighborhood: '',
    zip_code: ''
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('');
  const [clients, setClients] = useState<Client[]>([]);
  const [isLoadingClients, setIsLoadingClients] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingClient, setEditingClient] = useState<string | null>(null);

  const initialFormState: ClientInput = {
    name: '',
    cpf: '',
    birth_date: '',
    phone: '',
    email: '',
    address: '',
    address_number: '',
    neighborhood: '',
    zip_code: ''
  };

  useEffect(() => {
    loadClients();
  }, [searchTerm, selectedStatus]);

  const loadClients = async () => {
    setIsLoadingClients(true);
    try {
      const data = await clientService.getClients(searchTerm, selectedStatus);
      setClients(data);
    } catch (err) {
      console.error('Error loading clients:', err);
      setError('Erro ao carregar clientes');
    } finally {
      setIsLoadingClients(false);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      if (!formData.name || !formData.cpf || !formData.phone || !formData.address) {
        throw new Error('Nome, CPF, Telefone e Endereço são obrigatórios');
      }

      await clientService.createClient(formData);
      setSuccessMessage('Cliente salvo com sucesso!');
      setFormData(initialFormState);
      setShowForm(false);
      loadClients();

      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar cliente');
    } finally {
      setIsLoading(false);
    }
  };

  const handleClear = () => {
    setFormData(initialFormState);
    setEditingClient(null);
    setError(null);
    setSuccessMessage(null);
    setShowForm(true);
  };

  const handleCancel = () => {
    if (confirm('Deseja realmente cancelar? Todas as alterações serão perdidas.')) {
      handleClear();
      setShowForm(false);
    }
  };

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Clientes</h1>
        <button 
          onClick={handleClear}
          className="flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
        >
          <Plus className="w-5 h-5 mr-2" />
          Novo Cliente
        </button>
      </div>

      {successMessage && (
        <div className="mb-6 p-4 bg-green-50 border border-green-200 text-green-600 rounded-lg">
          {successMessage}
        </div>
      )}

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-600 rounded-lg">
          {error}
        </div>
      )}

      <div className="bg-white rounded-lg shadow-md p-6">
        {showForm && (
          <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <div>
              <h2 className="text-lg font-semibold mb-4">Dados Pessoais</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nome Completo <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    required
                  />
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      CPF <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={formData.cpf}
                      onChange={(e) => setFormData({ ...formData, cpf: e.target.value })}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Data de Nascimento</label>
                    <input
                      type="date"
                      value={formData.birth_date}
                      onChange={(e) => setFormData({ ...formData, birth_date: e.target.value })}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div>
              <h2 className="text-lg font-semibold mb-4">Contato</h2>
              <div className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="relative">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Telefone <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="tel"
                        value={formData.phone}
                        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        required
                      />
                      <Phone className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                  <div className="relative">
                    <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                    <div className="relative">
                      <input
                        type="email"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      />
                      <Mail className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Endereço <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      value={formData.address}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                    <MapPin className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Número <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={formData.address_number}
                      onChange={(e) => setFormData({ ...formData, address_number: e.target.value })}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Bairro <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={formData.neighborhood}
                      onChange={(e) => setFormData({ ...formData, neighborhood: e.target.value })}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      CEP <span className="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={formData.zip_code}
                      onChange={(e) => setFormData({ ...formData, zip_code: e.target.value })}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="col-span-2 flex justify-end gap-4 mt-6">
              <button
                type="button"
                onClick={handleCancel}
                className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={handleClear}
                className="px-4 py-2 text-purple-600 bg-purple-100 rounded-lg hover:bg-purple-200 transition-colors"
              >
                Limpar
              </button>
              <button
                type="submit"
                disabled={isLoading}
                className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:bg-purple-400 disabled:cursor-not-allowed flex items-center justify-center"
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                    Salvando...
                  </>
                ) : (
                  'Salvar'
                )}
              </button>
            </div>
          </form>
        )}

        <div className="border-t pt-6">
          <div className="flex gap-4 mb-6">
            <div className="flex-1 relative">
              <input
                type="text"
                placeholder="Buscar clientes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
              />
              <Search className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
            </div>
            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
              className="px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
            >
              <option value="">Todos os Status</option>
              <option value="active">Ativos</option>
              <option value="inactive">Inativos</option>
            </select>
          </div>

          <div className="mb-8">
            <h2 className="text-lg font-semibold mb-4">Lista de Clientes</h2>
            {isLoadingClients ? (
              <div className="flex justify-center items-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
              </div>
            ) : clients.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50">
                      <th className="px-4 py-2 text-left">Nome</th>
                      <th className="px-4 py-2 text-left">CPF</th>
                      <th className="px-4 py-2 text-left">Telefone</th>
                      <th className="px-4 py-2 text-left">Email</th>
                      <th className="px-4 py-2 text-left">Status</th>
                      <th className="px-4 py-2 text-center">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {clients.map((client) => (
                      <tr key={client.id} className="border-t hover:bg-gray-50">
                        <td className="px-4 py-2">{client.name}</td>
                        <td className="px-4 py-2">{client.cpf}</td>
                        <td className="px-4 py-2">{client.phone}</td>
                        <td className="px-4 py-2">{client.email}</td>
                        <td className="px-4 py-2">
                          <span className={`px-2 py-1 rounded-full text-sm ${
                            client.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                          }`}>
                            {client.status === 'active' ? 'Ativo' : 'Inativo'}
                          </span>
                        </td>
                        <td className="px-4 py-2 text-center">
                          <button
                            onClick={() => {
                              setFormData({
                                name: client.name,
                                cpf: client.cpf,
                                birth_date: client.birth_date || '',
                                phone: client.phone || '',
                                email: client.email || '',
                                address: client.address || '',
                                address_number: client.address_number || '',
                                neighborhood: client.neighborhood || '',
                                zip_code: client.zip_code || ''
                              });
                              setEditingClient(client.id);
                              setShowForm(true);
                            }}
                            className="p-1 text-purple-600 hover:bg-purple-50 rounded-full transition-colors"
                            title="Editar"
                          >
                            <Pencil className="w-5 h-5" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-center text-gray-500 py-8">Nenhum cliente encontrado</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Clientes;