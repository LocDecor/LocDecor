import React, { useState, FormEvent, useEffect } from 'react';
import { Search, Plus, Package, DollarSign, Tag, Image, Loader2, Pencil } from 'lucide-react';
import { inventoryService, InventoryItemInput } from '../services/inventoryService';
import { InventoryItem } from '../types/database';

const Acervo = () => {
  const [formData, setFormData] = useState<InventoryItemInput>({
    name: '',
    category: '',
    description: '',
    rental_price: undefined,
    acquisition_price: undefined,
    current_stock: undefined,
    min_stock: undefined
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [items, setItems] = useState<InventoryItem[]>([]);
  const [isLoadingItems, setIsLoadingItems] = useState(false);
  const [editingItem, setEditingItem] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);

  const categories = [
    'MÓVEIS',
    'SUPORTES',
    'ESTRUTURA',
    'CAPAS',
    'BANDEJAS',
    'VASOS',
    'BOLEIRAS',
    'ARRANJOS',
    'ENFEITES',
    'BOLO FAKES',
    'TAPETES',
    'LETREIROS'
  ];

  const initialFormState: InventoryItemInput = {
    name: '',
    category: '',
    description: '',
    rental_price: undefined,
    acquisition_price: undefined,
    current_stock: undefined,
    min_stock: undefined
  };

  useEffect(() => {
    loadItems();
  }, [searchTerm, selectedCategory]);

  const loadItems = async () => {
    setIsLoadingItems(true);
    try {
      const data = await inventoryService.getItems(searchTerm, selectedCategory);
      setItems(data);
    } catch (err) {
      console.error('Error loading items:', err);
      setError('Erro ao carregar itens');
    } finally {
      setIsLoadingItems(false);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      if (!formData.name || !formData.category) {
        throw new Error('Nome e categoria são obrigatórios');
      }

      if (editingItem) {
        await inventoryService.updateItem(editingItem, formData);
        setSuccessMessage('Item atualizado com sucesso!');
      } else {
        await inventoryService.createItem(formData);
        setSuccessMessage('Item salvo com sucesso!');
      }

      setFormData(initialFormState);
      setEditingItem(null);
      setShowForm(false);
      loadItems();

      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar item');
    } finally {
      setIsLoading(false);
    }
  };

  const handleEdit = async (itemId: string) => {
    try {
      const item = await inventoryService.getItemById(itemId);
      if (item) {
        setFormData({
          name: item.name,
          category: item.category,
          description: item.description || '',
          rental_price: item.rental_price,
          acquisition_price: item.acquisition_price,
          current_stock: item.current_stock,
          min_stock: item.min_stock
        });
        setEditingItem(itemId);
        setShowForm(true);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    } catch (err) {
      setError('Erro ao carregar item para edição');
    }
  };

  const handleClear = () => {
    setFormData(initialFormState);
    setEditingItem(null);
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
        <h1 className="text-2xl font-bold text-gray-800">Acervo</h1>
        <button 
          onClick={handleClear}
          className="flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
        >
          <Plus className="w-5 h-5 mr-2" />
          Novo Item
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
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div>
              <h2 className="text-lg font-semibold mb-4">
                {editingItem ? 'Editar Item' : 'Novo Item'}
              </h2>
              <div className="space-y-4">
                <div className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nome do Item <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                    <Package className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Categoria <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    required
                  >
                    <option value="">Selecione uma categoria</option>
                    {categories.map((category) => (
                      <option key={category} value={category}>{category}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                  <textarea
                    rows={4}
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  ></textarea>
                </div>
              </div>
            </div>

            <div>
              <h2 className="text-lg font-semibold mb-4">Detalhes do Estoque</h2>
              <div className="space-y-4">
                <div className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Valor de Aluguel <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      step="0.01"
                      value={formData.rental_price || ''}
                      onChange={(e) => setFormData({ ...formData, rental_price: e.target.value ? parseFloat(e.target.value) : undefined })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                    <DollarSign className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                  </div>
                </div>
                <div className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Valor de Aquisição</label>
                  <div className="relative">
                    <input
                      type="number"
                      step="0.01"
                      value={formData.acquisition_price || ''}
                      onChange={(e) => setFormData({ ...formData, acquisition_price: e.target.value ? parseFloat(e.target.value) : undefined })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    />
                    <DollarSign className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Quantidade em Estoque</label>
                  <input
                    type="number"
                    value={formData.current_stock || ''}
                    onChange={(e) => setFormData({ ...formData, current_stock: e.target.value ? parseInt(e.target.value) : undefined })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Estoque Mínimo</label>
                  <input
                    type="number"
                    value={formData.min_stock || ''}
                    onChange={(e) => setFormData({ ...formData, min_stock: e.target.value ? parseInt(e.target.value) : undefined })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Fotos do Item</label>
                  <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
                    <Image className="w-8 h-8 mx-auto mb-2 text-gray-400" />
                    <p className="text-sm text-gray-500">Arraste as fotos ou clique para fazer upload</p>
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
                    {editingItem ? 'Atualizando...' : 'Salvando...'}
                  </>
                ) : (
                  editingItem ? 'Atualizar' : 'Salvar'
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
                placeholder="Buscar no acervo..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
              />
              <Search className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
            </div>
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
            >
              <option value="">Todas as Categorias</option>
              {categories.map((category) => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>
          </div>

          <div className="mb-8">
            <h2 className="text-lg font-semibold mb-4">Lista de Itens</h2>
            {isLoadingItems ? (
              <div className="flex justify-center items-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
              </div>
            ) : items.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50">
                      <th className="px-4 py-2 text-left">Código</th>
                      <th className="px-4 py-2 text-left">Nome</th>
                      <th className="px-4 py-2 text-left">Categoria</th>
                      <th className="px-4 py-2 text-right">Valor Aluguel</th>
                      <th className="px-4 py-2 text-center">Estoque</th>
                      <th className="px-4 py-2 text-left">Status</th>
                      <th className="px-4 py-2 text-center">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((item) => (
                      <tr key={item.id} className="border-t hover:bg-gray-50">
                        <td className="px-4 py-2">{item.code}</td>
                        <td className="px-4 py-2">{item.name}</td>
                        <td className="px-4 py-2">{item.category}</td>
                        <td className="px-4 py-2 text-right">
                          R$ {item.rental_price.toFixed(2)}
                        </td>
                        <td className="px-4 py-2 text-center">
                          <span className={`${
                            item.current_stock <= item.min_stock
                              ? 'text-red-600'
                              : 'text-green-600'
                          }`}>
                            {item.current_stock}
                          </span>
                        </td>
                        <td className="px-4 py-2">
                          <span className={`px-2 py-1 rounded-full text-sm ${
                            item.status === 'active'
                              ? 'bg-green-100 text-green-800'
                              : 'bg-gray-100 text-gray-800'
                          }`}>
                            {item.status === 'active' ? 'Ativo' : 'Inativo'}
                          </span>
                        </td>
                        <td className="px-4 py-2 text-center">
                          <button
                            onClick={() => handleEdit(item.id)}
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
              <p className="text-center text-gray-500 py-8">Nenhum item encontrado</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Acervo;