import React, { useState, FormEvent, useEffect } from 'react';
import { Search, Plus, Calendar, DollarSign, ArrowUpRight, ArrowDownRight, Loader2, Pencil, X } from 'lucide-react';
import { transactionService, TransactionInput } from '../services/transactionService';
import { Transaction } from '../types/database';

const Financeiro = () => {
  const [formData, setFormData] = useState<TransactionInput>({
    type: 'receita',
    amount: 0,
    category: '',
    date: new Date().toISOString().split('T')[0],
    description: '',
    payment_method: '',
    status: 'pending'
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [isLoadingTransactions, setIsLoadingTransactions] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState<string | null>(null);

  const initialFormState: TransactionInput = {
    type: 'receita',
    amount: 0,
    category: '',
    date: new Date().toISOString().split('T')[0],
    description: '',
    payment_method: '',
    status: 'pending'
  };

  useEffect(() => {
    loadTransactions();
  }, [searchTerm, selectedType]);

  const loadTransactions = async () => {
    setIsLoadingTransactions(true);
    try {
      const data = await transactionService.getTransactions(searchTerm, selectedType);
      setTransactions(data);
    } catch (err) {
      console.error('Error loading transactions:', err);
      setError('Erro ao carregar transações');
    } finally {
      setIsLoadingTransactions(false);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      if (!formData.amount || !formData.category || !formData.date) {
        throw new Error('Valor, categoria e data são obrigatórios');
      }

      if (editingTransaction) {
        await transactionService.updateTransaction(editingTransaction, formData);
        setSuccessMessage('Transação atualizada com sucesso!');
      } else {
        await transactionService.createTransaction(formData);
        setSuccessMessage('Transação salva com sucesso!');
      }

      setFormData(initialFormState);
      setEditingTransaction(null);
      setShowForm(false);
      loadTransactions();

      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar transação');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Deseja realmente excluir esta transação?')) {
      return;
    }

    try {
      await transactionService.deleteTransaction(id);
      setSuccessMessage('Transação excluída com sucesso!');
      loadTransactions();

      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir transação');
    }
  };

  const handleClear = () => {
    setFormData(initialFormState);
    setEditingTransaction(null);
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
        <h1 className="text-2xl font-bold text-gray-800">Financeiro</h1>
        <div className="flex gap-2">
          <button 
            onClick={() => {
              setFormData({ ...initialFormState, type: 'receita' });
              setShowForm(true);
            }}
            className="flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <ArrowUpRight className="w-5 h-5 mr-2" />
            Nova Receita
          </button>
          <button 
            onClick={() => {
              setFormData({ ...initialFormState, type: 'despesa' });
              setShowForm(true);
            }}
            className="flex items-center px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            <ArrowDownRight className="w-5 h-5 mr-2" />
            Nova Despesa
          </button>
        </div>
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
                {formData.type === 'receita' ? 'Nova Receita' : 'Nova Despesa'}
              </h2>
              <div className="space-y-4">
                <div className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Valor <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      step="0.01"
                      value={formData.amount}
                      onChange={(e) => setFormData({ ...formData, amount: parseFloat(e.target.value) })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                    <DollarSign className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
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
                    {formData.type === 'receita' ? (
                      <>
                        <option value="vendas">Vendas</option>
                        <option value="servicos">Serviços</option>
                        <option value="aluguel">Aluguel</option>
                        <option value="outros">Outros</option>
                      </>
                    ) : (
                      <>
                        <option value="fornecedores">Fornecedores</option>
                        <option value="salarios">Salários</option>
                        <option value="marketing">Marketing</option>
                        <option value="infraestrutura">Infraestrutura</option>
                        <option value="outros">Outros</option>
                      </>
                    )}
                  </select>
                </div>

                <div className="relative">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Data <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="date"
                      value={formData.date}
                      onChange={(e) => setFormData({ ...formData, date: e.target.value })}
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                      required
                    />
                    <Calendar className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
                  </div>
                </div>
              </div>
            </div>

            <div>
              <h2 className="text-lg font-semibold mb-4">Detalhes Adicionais</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                  <textarea
                    rows={4}
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  ></textarea>
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
                    <option value="transfer">Transferência Bancária</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                  <select
                    value={formData.status}
                    onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
                  >
                    <option value="pending">Pendente</option>
                    <option value="completed">Pago</option>
                    <option value="scheduled">Agendado</option>
                  </select>
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
                    {editingTransaction ? 'Atualizando...' : 'Salvando...'}
                  </>
                ) : (
                  editingTransaction ? 'Atualizar' : 'Salvar'
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
                placeholder="Buscar transações..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
              />
              <Search className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
            </div>
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
            >
              <option value="">Todas as Transações</option>
              <option value="receita">Receitas</option>
              <option value="despesa">Despesas</option>
            </select>
          </div>

          <div className="mb-8">
            <h2 className="text-lg font-semibold mb-4">Lista de Transações</h2>
            {isLoadingTransactions ? (
              <div className="flex justify-center items-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
              </div>
            ) : transactions.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50">
                      <th className="px-4 py-2 text-left">Data</th>
                      <th className="px-4 py-2 text-left">Tipo</th>
                      <th className="px-4 py-2 text-left">Categoria</th>
                      <th className="px-4 py-2 text-left">Descrição</th>
                      <th className="px-4 py-2 text-right">Valor</th>
                      <th className="px-4 py-2 text-left">Status</th>
                      <th className="px-4 py-2 text-center">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    {transactions.map((transaction) => (
                      <tr key={transaction.id} className="border-t hover:bg-gray-50">
                        <td className="px-4 py-2">
                          {new Date(transaction.date).toLocaleDateString()}
                        </td>
                        <td className="px-4 py-2">
                          <span className={`px-2 py-1 rounded-full text-sm ${
                            transaction.type === 'receita'
                              ? 'bg-green-100 text-green-800'
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {transaction.type === 'receita' ? 'Receita' : 'Despesa'}
                          </span>
                        </td>
                        <td className="px-4 py-2">{transaction.category}</td>
                        <td className="px-4 py-2">{transaction.description}</td>
                        <td className="px-4 py-2 text-right">
                          <span className={transaction.type === 'receita' ? 'text-green-600' : 'text-red-600'}>
                            R$ {transaction.amount.toFixed(2)}
                          </span>
                        </td>
                        <td className="px-4 py-2">
                          <span className={`px-2 py-1 rounded-full text-sm ${
                            transaction.status === 'completed'
                              ? 'bg-green-100 text-green-800'
                              : transaction.status === 'scheduled'
                              ? 'bg-blue-100 text-blue-800'
                              : 'bg-yellow-100 text-yellow-800'
                          }`}>
                            {transaction.status === 'completed'
                              ? 'Pago'
                              : transaction.status === 'scheduled'
                              ? 'Agendado'
                              : 'Pendente'}
                          </span>
                        </td>
                        <td className="px-4 py-2">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => {
                                setFormData({
                                  type: transaction.type,
                                  amount: transaction.amount,
                                  category: transaction.category,
                                  date: transaction.date,
                                  description: transaction.description || '',
                                  payment_method: transaction.payment_method || '',
                                  status: transaction.status
                                });
                                setEditingTransaction(transaction.id);
                                setShowForm(true);
                              }}
                              className="p-1 text-purple-600 hover:bg-purple-50 rounded-full transition-colors"
                              title="Editar"
                            >
                              <Pencil className="w-5 h-5" />
                            </button>
                            <button
                              onClick={() => handleDelete(transaction.id)}
                              className="p-1 text-red-600 hover:bg-red-50 rounded-full transition-colors"
                              title="Excluir"
                            >
                              <X className="w-5 h-5" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-center text-gray-500 py-8">Nenhuma transação encontrada</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Financeiro;