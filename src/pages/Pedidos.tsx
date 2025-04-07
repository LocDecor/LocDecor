import React, { useState, FormEvent, useEffect } from 'react';
import { Search, Plus, Calendar, Clock, DollarSign, FileText, Package, Loader2, Pencil, X, AlertTriangle } from 'lucide-react';
import { orderService, OrderInput } from '../services/orderService';
import { Order, Client, InventoryItem } from '../types/database';

interface OrderItemInput {
  item_id: string;
  quantity: number;
  unit_price: number;
  item: InventoryItem;
}

const Pedidos = () => {
  const [formData, setFormData] = useState<OrderInput>({
    client_id: '',
    plan: '',
    order_status: '',
    payment_status: '',
    pickup_date: '',
    pickup_time: '',
    return_date: '',
    return_time: '',
    total_amount: '',
    payment_method: '',
    notes: ''
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('');
  const [orders, setOrders] = useState<Order[]>([]);
  const [isLoadingOrders, setIsLoadingOrders] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingOrder, setEditingOrder] = useState<string | null>(null);
  const [clientSearchTerm, setClientSearchTerm] = useState('');
  const [clientSuggestions, setClientSuggestions] = useState<Client[]>([]);
  const [isLoadingClients, setIsLoadingClients] = useState(false);
  const [showClientSuggestions, setShowClientSuggestions] = useState(false);
  const [selectedClient, setSelectedClient] = useState<Client | null>(null);
  const [showCancelConfirm, setShowCancelConfirm] = useState<string | null>(null);
  const [isCanceling, setIsCanceling] = useState(false);
  const [isGeneratingContract, setIsGeneratingContract] = useState(false);
  const [contractContent, setContractContent] = useState<string | null>(null);

  // Item management state
  const [itemSearchTerm, setItemSearchTerm] = useState('');
  const [itemSuggestions, setItemSuggestions] = useState<InventoryItem[]>([]);
  const [isLoadingItems, setIsLoadingItems] = useState(false);
  const [showItemSuggestions, setShowItemSuggestions] = useState(false);
  const [selectedItems, setSelectedItems] = useState<OrderItemInput[]>([]);
  const [itemQuantity, setItemQuantity] = useState(1);
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  const initialFormState = {
    client_id: '',
    plan: '',
    order_status: '',
    payment_status: '',
    pickup_date: '',
    pickup_time: '',
    return_date: '',
    return_time: '',
    total_amount: '',
    payment_method: '',
    notes: ''
  };

  useEffect(() => {
    loadOrders();
  }, [searchTerm, selectedStatus]);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (clientSearchTerm) {
        loadClientSuggestions();
      } else {
        setClientSuggestions([]);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [clientSearchTerm]);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (itemSearchTerm) {
        loadItemSuggestions();
      } else {
        setItemSuggestions([]);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [itemSearchTerm]);

  const loadClientSuggestions = async () => {
    setIsLoadingClients(true);
    try {
      const data = await orderService.getClients(clientSearchTerm);
      setClientSuggestions(data);
    } catch (err) {
      console.error('Error loading clients:', err);
    } finally {
      setIsLoadingClients(false);
    }
  };

  const loadItemSuggestions = async () => {
    setIsLoadingItems(true);
    try {
      const data = await orderService.getInventoryItems(itemSearchTerm);
      setItemSuggestions(data);
    } catch (err) {
      console.error('Error loading items:', err);
    } finally {
      setIsLoadingItems(false);
    }
  };

  const handleClientSelect = (client: Client) => {
    setSelectedClient(client);
    setFormData(prev => ({ ...prev, client_id: client.id }));
    setClientSearchTerm(client.name);
    setShowClientSuggestions(false);
  };

  const handleItemSelect = (item: InventoryItem) => {
    setSelectedItem(item);
  };

  const handleAddItem = () => {
    if (!selectedItem) return;

    if (itemQuantity <= 0) {
      setError('A quantidade deve ser maior que zero');
      return;
    }

    if (itemQuantity > selectedItem.current_stock) {
      setError(`Quantidade disponível insuficiente. Máximo: ${selectedItem.current_stock}`);
      return;
    }

    const newItem: OrderItemInput = {
      item_id: selectedItem.id,
      quantity: itemQuantity,
      unit_price: selectedItem.rental_price,
      item: selectedItem
    };

    setSelectedItems(prev => [...prev, newItem]);
    setItemSearchTerm('');
    setSelectedItem(null);
    setItemQuantity(1);
    setShowItemSuggestions(false);
    setError(null);

    // Update total amount
    const newTotal = selectedItems.reduce((sum, item) => 
      sum + (item.quantity * item.unit_price), 0) + (itemQuantity * selectedItem.rental_price);
    
    setFormData(prev => ({
      ...prev,
      total_amount: newTotal.toString()
    }));
  };

  const handleRemoveItem = (index: number) => {
    setSelectedItems(prev => {
      const newItems = [...prev];
      newItems.splice(index, 1);

      // Update total amount
      const newTotal = newItems.reduce((sum, item) => 
        sum + (item.quantity * item.unit_price), 0);
      
      setFormData(prev => ({
        ...prev,
        total_amount: newTotal.toString()
      }));

      return newItems;
    });
  };

  const loadOrders = async () => {
    setIsLoadingOrders(true);
    try {
      const data = await orderService.getOrders(searchTerm, selectedStatus);
      setOrders(data);
    } catch (err) {
      console.error('Error loading orders:', err);
      setError('Erro ao carregar pedidos');
    } finally {
      setIsLoadingOrders(false);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      if (!formData.client_id || !formData.plan || !formData.pickup_date || !formData.return_date) {
        throw new Error('Cliente, plano e datas são obrigatórios');
      }

      if (selectedItems.length === 0) {
        throw new Error('Adicione pelo menos um item ao pedido');
      }

      const orderData = {
        ...formData,
        items: selectedItems.map(item => ({
          item_id: item.item_id,
          quantity: item.quantity,
          unit_price: item.unit_price
        }))
      };

      if (editingOrder) {
        await orderService.updateOrder(editingOrder, orderData as OrderInput);
        setSuccessMessage('Pedido atualizado com sucesso!');
      } else {
        await orderService.createOrder(orderData as OrderInput);
        setSuccessMessage('Pedido salvo com sucesso!');
      }

      setFormData(initialFormState);
      setSelectedItems([]);
      setEditingOrder(null);
      setShowForm(false);
      loadOrders();

      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar pedido');
    } finally {
      setIsLoading(false);
    }
  };

  const handleClear = () => {
    setFormData(initialFormState);
    setEditingOrder(null);
    setError(null);
    setSuccessMessage(null);
    setSelectedClient(null);
    setClientSearchTerm('');
    setSelectedItems([]);
    setShowForm(true);
  };

  const handleCancel = () => {
    if (confirm('Deseja realmente cancelar? Todas as alterações serão perdidas.')) {
      handleClear();
      setShowForm(false);
    }
  };

  const handleCancelOrder = async (orderId: string) => {
    setIsCanceling(true);
    try {
      await orderService.cancelOrder(orderId);
      setSuccessMessage('Pedido cancelado com sucesso!');
      loadOrders();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao cancelar pedido');
    } finally {
      setIsCanceling(false);
      setShowCancelConfirm(null);
    }
  };

  const handleGenerateContract = async (orderId: string) => {
    setIsGeneratingContract(true);
    try {
      const content = await orderService.generateContract(orderId);
      setContractContent(content);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao gerar contrato');
    } finally {
      setIsGeneratingContract(false);
    }
  };

  const handlePrintContract = () => {
    if (contractContent) {
      const printWindow = window.open('', '_blank');
      if (printWindow) {
        printWindow.document.write(`
          <html>
            <head>
              <title>Contrato de Locação</title>
              <style>
                body {
                  font-family: Arial, sans-serif;
                  line-height: 1.6;
                  padding: 20px;
                }
                pre {
                  white-space: pre-wrap;
                  font-family: Arial, sans-serif;
                }
              </style>
            </head>
            <body>
              <pre>${contractContent}</pre>
            </body>
          </html>
        `);
        printWindow.document.close();
        printWindow.print();
      }
    }
  };

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Pedidos</h1>
        <button 
          onClick={handleClear}
          className="flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
        >
          <Plus className="w-5 h-5 mr-2" />
          Novo Pedido
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
              <h2 className="text-lg font-semibold mb-4">
                {editingOrder ? 'Editar Pedido' : 'Novo Pedido'}
              </h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Cliente <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      value={clientSearchTerm}
                      onChange={(e) => {
                        setClientSearchTerm(e.target.value);
                        setShowClientSuggestions(true);
                      }}
                      onFocus={() => setShowClientSuggestions(true)}
                      placeholder="Digite o nome do cliente..."
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    />
                    {isLoadingClients && (
                      <div className="absolute right-3 top-2.5">
                        <Loader2 className="w-5 h-5 animate-spin text-purple-600" />
                      </div>
                    )}
                    {showClientSuggestions && clientSuggestions.length > 0 && (
                      <div className="absolute z-10 w-full mt-1 bg-white border rounded-lg shadow-lg">
                        {clientSuggestions.map((client) => (
                          <div
                            key={client.id}
                            onClick={() => handleClientSelect(client)}
                            className="px-4 py-2 hover:bg-purple-50 cursor-pointer"
                          >
                            <div className="font-medium">{client.name}</div>
                            <div className="text-sm text-gray-500">
                              {client.phone} - {client.cpf}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  {selectedClient && (
                    <div className="mt-2 p-2 bg-gray-50 rounded-lg text-sm">
                      <p><strong>Cliente selecionado:</strong></p>
                      <p>Nome: {selectedClient.name}</p>
                      <p>Telefone: {selectedClient.phone}</p>
                      <p>Endereço: {selectedClient.address}, {selectedClient.address_number}</p>
                    </div>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Status do Pagamento <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.payment_status}
                    onChange={(e) => setFormData({ ...formData, payment_status: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    required
                  >
                    <option value="">Selecione o status do pagamento</option>
                    <option value="SINAL 50%">SINAL 50%</option>
                    <option value="COMPLETO">COMPLETO</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Plano <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.plan}
                    onChange={(e) => setFormData({ ...formData, plan: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    required
                  >
                    <option value="">Selecione o plano</option>
                    <option value="MINI DECORAÇÃO">MINI DECORAÇÃO</option>
                    <option value="BRONZE">BRONZE</option>
                    <option value="PRATA">PRATA</option>
                    <option value="OURO">OURO</option>
                    <option value="COMPOSICAO">COMPOSIÇÃO</option>
                  </select>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Data de Retirada <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="date"
                        value={formData.pickup_date}
                        onChange={(e) => setFormData({ ...formData, pickup_date: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        required
                      />
                      <Calendar className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Horário de Retirada <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="time"
                        value={formData.pickup_time}
                        onChange={(e) => setFormData({ ...formData, pickup_time: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        required
                      />
                      <Clock className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Data de Devolução <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="date"
                        value={formData.return_date}
                        onChange={(e) => setFormData({ ...formData, return_date: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        required
                      />
                      <Calendar className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Horário de Devolução <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <input
                        type="time"
                        value={formData.return_time}
                        onChange={(e) => setFormData({ ...formData, return_time: e.target.value })}
                        className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        required
                      />
                      <Clock className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div>
              <h2 className="text-lg font-semibold mb-4">Itens e Valores</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Itens do Pedido <span className="text-red-500">*</span>
                  </label>
                  <div className="border rounded-lg p-4 space-y-4">
                    <div className="flex items-center gap-2">
                      <div className="relative flex-1">
                        <input
                          type="text"
                          value={itemSearchTerm}
                          onChange={(e) => {
                            setItemSearchTerm(e.target.value);
                            setShowItemSuggestions(true);
                          }}
                          onFocus={() => setShowItemSuggestions(true)}
                          placeholder="Buscar item..."
                          className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        />
                        <Package className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                        {isLoadingItems && (
                          <div className="absolute right-3 top-2.5">
                            <Loader2 className="w-5 h-5 animate-spin text-purple-600" />
                          </div>
                        )}
                        {showItemSuggestions && itemSuggestions.length > 0 && (
                          <div className="absolute z-10 w-full mt-1 bg-white border rounded-lg shadow-lg max-h-60 overflow-auto">
                            {itemSuggestions.map((item) => (
                              <div
                                key={item.id}
                                onClick={() => handleItemSelect(item)}
                                className="px-4 py-2 hover:bg-purple-50 cursor-pointer"
                              >
                                <div className="font-medium">{item.name}</div>
                                <div className="text-sm text-gray-500">
                                  {item.category} - R$ {item.rental_price.toFixed(2)}
                                </div>
                                <div className="text-sm text-gray-500">
                                  Disponível: {item.current_stock} unidades
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                      <input
                        type="number"
                        min="1"
                        value={itemQuantity}
                        onChange={(e) => setItemQuantity(parseInt(e.target.value) || 1)}
                        className="w-24 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                        placeholder="Qtd"
                      />
                      <button
                        type="button"
                        onClick={handleAddItem}
                        disabled={!selectedItem}
                        className="px-3 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:bg-purple-300"
                      >
                        <Plus className="w-5 h-5" />
                      </button>
                    </div>

                    {selectedItems.length > 0 && (
                      <div className="mt-4">
                        <h4 className="text-sm font-medium text-gray-700 mb-2">Itens Selecionados:</h4>
                        <div className="space-y-2">
                          {selectedItems.map((item, index) => (
                            <div key={index} className="flex items-center justify-between bg-gray-50 p-2 rounded-lg">
                              <div>
                                <div className="font-medium">{item.item.name}</div>
                                <div className="text-sm text-gray-500">
                                  {item.quantity} x R$ {item.unit_price.toFixed(2)} = R$ {(item.quantity * item.unit_price).toFixed(2)}
                                </div>
                              </div>
                              <button
                                type="button"
                                onClick={() => handleRemoveItem(index)}
                                className="p-1 text-red-600 hover:bg-red-50 rounded-full transition-colors"
                              >
                                <X className="w-5 h-5" />
                              </button>
                            </div>
                          ))}
                          <div className="text-right text-sm font-medium text-gray-700 pt-2 border-t">
                            Total: R$ {selectedItems.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0).toFixed(2)}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Forma de Pagamento <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.payment_method}
                    onChange={(e) => setFormData({ ...formData, payment_method: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                    required
                  >
                    <option value="">Selecione a forma de pagamento</option>
                    <option value="pix">PIX</option>
                    <option value="credit">Cartão de Crédito</option>
                    <option value="debit">Cartão de Débito</option>
                    <option value="cash">Dinheiro</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Observações</label>
                  <textarea
                    rows={3}
                    value={formData.notes}
                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  ></textarea>
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
                    {editingOrder ? 'Atualizando...' : 'Salvando...'}
                  </>
                ) : (
                  editingOrder ? 'Atualizar' : 'Salvar'
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
                placeholder="Buscar pedidos..."
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
              <option value="pending">Pendente</option>
              <option value="active">Ativo</option>
              <option value="completed">Concluído</option>
              <option value="canceled">Cancelado</option>
            </select>
          </div>

          <div className="mb-8">
            <h2 className="text-lg font-semibold mb-4">Lista de Pedidos</h2>
            {isLoadingOrders ? (
              <div className="flex justify-center items-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
              </div>
            ) : orders.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50">
                      <th className="px-4 py-2 text-left">Pedido N°</th>
                      <th className="px-4 py-2 text-left">Cliente</th>
                      <th className="px-4 py-2 text-left">Plano</th>
                      <th className="px-4 py-2 text-left">Retirada</th>
                      <th className="px-4 py-2 text-left">Devolução</th>
                      <th className="px-4 py-2 text-right">Valor Total</th>
                      <th className="px-4 py-2 text-left">Status</th>
                      <th className="px-4 py-2 text-center">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((order) => (
                      <tr key={order.id} className="border-t hover:bg-gray-50">
                        <td className="px-4 py-2">{order.order_number}</td>
                        <td className="px-4 py-2">{order.client?.name}</td>
                        <td className="px-4 py-2">{order.plan}</td>
                        <td className="px-4 py-2">
                          {new Date(order.pickup_date).toLocaleDateString()} {order.pickup_time}
                        </td>
                        <td className="px-4 py-2">
                          {new Date(order.return_date).toLocaleDateString()} {order.return_time}
                        </td>
                        <td className="px-4 py-2 text-right">
                          R$ {Number(order.total_amount).toFixed(2)}
                        </td>
                        <td className="px-4 py-2">
                          <span className={`px-2 py-1 rounded-full text-sm ${
                            order.order_status === 'completed'
                              ? 'bg-green-100 text-green-800'
                              : order.order_status === 'active'
                              ? 'bg-blue-100 text-blue-800'
                              : order.order_status === 'canceled'
                              ? 'bg-red-100 text-red-800'
                              : 'bg-yellow-100 text-yellow-800'
                          }`}>
                            {order.order_status === 'completed'
                              ? 'Concluído'
                              : order.order_status === 'active'
                              ? 'Ativo'
                              : order.order_status === 'canceled'
                              ? 'Cancelado'
                              : 'Pendente'}
                          </span>
                        </td>
                        <td className="px-4 py-2">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => {
                                setFormData({
                                  ...order,
                                  client_id: order.client_id || '',
                                });
                                setEditingOrder(order.id);
                                setShowForm(true);
                              }}
                              className="p-1 text-purple-600 hover:bg-purple-50 rounded-full transition-colors"
                              title="Editar"
                            >
                              <Pencil className="w-5 h-5" />
                            </button>
                            {order.order_status !== 'canceled' && (
                              <button
                                onClick={() => setShowCancelConfirm(order.id)}
                                className="p-1 text-red-600 hover:bg-red-50 rounded-full transition-colors"
                                title="Cancelar"
                                disabled={isCanceling}
                              >
                                <X className="w-5 h-5" />
                              </button>
                            )}
                            <button
                              onClick={() => handleGenerateContract(order.id)}
                              className="p-1 text-blue-600 hover:bg-blue-50 rounded-full transition-colors"
                              title="Gerar Contrato"
                              disabled={isGeneratingContract}
                            >
                              <FileText className="w-5 h-5" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-center text-gray-500 py-8">Nenhum pedido encontrado</p>
            )}
          </div>
        </div>
      </div>

      {/* Cancel Confirmation Modal */}
      {showCancelConfirm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <div className="flex items-center mb-4 text-red-600">
              <AlertTriangle className="w-6 h-6 mr-2" />
              <h3 className="text-lg font-semibold">Confirmar Cancelamento</h3>
            </div>
            <p className="text-gray-600 mb-6">
              Tem certeza que deseja cancelar este pedido? Esta ação não pode ser desfeita.
            </p>
            <div className="flex justify-end gap-4">
              <button
                onClick={() => setShowCancelConfirm(null)}
                className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isCanceling}
              >
                Não, manter pedido
              </button>
              <button
                onClick={() => handleCancelOrder(showCancelConfirm)}
                className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center"
                disabled={isCanceling}
              >
                {isCanceling && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                Sim, cancelar pedido
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Contract Preview Modal */}
      {contractContent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] flex flex-col">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Contrato de Locação</h3>
              <button
                onClick={() => setContractContent(null)}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="flex-1 overflow-auto">
              <pre className="whitespace-pre-wrap font-sans text-sm">
                {contractContent}
              </pre>
            </div>
            <div className="flex justify-end gap-4 mt-6 pt-4 border-t">
              <button
                onClick={() => setContractContent(null)}
                className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
              >
                Fechar
              </button>
              <button
                onClick={handlePrintContract}
                className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center"
              >
                <FileText className="w-5 h-5 mr-2" />
                Imprimir Contrato
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Pedidos;