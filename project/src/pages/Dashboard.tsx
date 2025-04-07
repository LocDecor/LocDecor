import React, { useState, useEffect, useCallback } from 'react';
import { 
  Calendar,
  Clock,
  AlertCircle,
  TrendingUp,
  Wallet,
  BarChart3,
  X,
  Printer,
  AlertTriangle,
  Package,
  FileText,
  Download,
  Filter,
  RefreshCw,
  Loader2,
  CheckCircle2,
  CheckSquare,
  ArrowUpCircle,
  ArrowRightCircle,
  CircleDot
} from 'lucide-react';
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  AreaChart,
  Area
} from 'recharts';
import { format, startOfMonth, endOfMonth, subMonths, isToday } from 'date-fns';
import { dashboardService } from '../services/dashboardService';
import { taskService } from '../services/taskService';
import { DashboardMetrics, ChartData, UpcomingPickup, Task } from '../types/database';
import TaskDetailsModal from '../components/TaskDetailsModal';

interface UpcomingPickupModalProps {
  pickup: UpcomingPickup;
  onClose: () => void;
  onPrint: (pickup: UpcomingPickup) => void;
  onConfirmPickup: () => void;
}

interface ConfirmationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
}

const UpcomingPickupModal: React.FC<UpcomingPickupModalProps> = ({ pickup, onClose, onPrint, onConfirmPickup }) => {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex justify-between items-center p-4 border-b">
          <h3 className="text-xl font-semibold">Detalhes da Retirada</h3>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 transition-colors p-2 hover:bg-gray-100 rounded-full"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
        <div className="p-6 overflow-y-auto flex-1">
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="font-medium text-gray-600">Cliente</p>
                <p className="text-lg">{pickup.client.name}</p>
              </div>
              <div>
                <p className="font-medium text-gray-600">Pedido N°</p>
                <p className="text-lg">{pickup.order_number}</p>
              </div>
              <div>
                <p className="font-medium text-gray-600">Data de Retirada</p>
                <p className="text-lg">
                  {new Date(pickup.pickup_date).toLocaleDateString()} às {pickup.pickup_time}
                </p>
              </div>
              <div>
                <p className="font-medium text-gray-600">Data de Devolução</p>
                <p className="text-lg">
                  {new Date(pickup.return_date).toLocaleDateString()} às {pickup.return_time}
                </p>
              </div>
              <div>
                <p className="font-medium text-gray-600">Valor Total</p>
                <p className="text-lg">R$ {pickup.total_amount.toFixed(2)}</p>
              </div>
            </div>

            <div>
              <p className="font-medium text-gray-600 mb-2">Itens do Pedido</p>
              <div className="space-y-2">
                {pickup.items.map((item, index) => (
                  <div key={index} className="flex justify-between items-center bg-gray-50 p-2 rounded-lg">
                    <div>
                      <p className="font-medium">{item.item.name}</p>
                      <p className="text-sm text-gray-500">{item.item.category}</p>
                    </div>
                    <div className="text-right">
                      <p className="font-medium">{item.quantity} unidades</p>
                      <p className="text-sm text-gray-500">
                        R$ {item.unit_price.toFixed(2)} cada
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
        <div className="border-t p-4 flex justify-end gap-4">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
          >
            Fechar
          </button>
          <button
            onClick={() => onPrint(pickup)}
            className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors flex items-center"
          >
            <Printer className="w-5 h-5 mr-2" />
            Imprimir
          </button>
          <button
            onClick={onConfirmPickup}
            className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center"
          >
            <CheckCircle2 className="w-5 h-5 mr-2" />
            Confirmar Retirada
          </button>
        </div>
      </div>
    </div>
  );
};

const ConfirmationModal: React.FC<ConfirmationModalProps> = ({ isOpen, onClose, onConfirm, title, message }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div className="flex items-center mb-4 text-red-600">
          <AlertTriangle className="w-6 h-6 mr-2" />
          <h3 className="text-lg font-semibold">{title}</h3>
        </div>
        <p className="text-gray-600 mb-6">{message}</p>
        <div className="flex justify-end gap-4">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={onConfirm}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Confirmar
          </button>
        </div>
      </div>
    </div>
  );
};

const Dashboard = () => {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [revenueData, setRevenueData] = useState<ChartData[]>([]);
  const [occupationData, setOccupationData] = useState<ChartData[]>([]);
  const [todayReturns, setTodayReturns] = useState<UpcomingPickup[]>([]);
  const [upcomingPickups, setUpcomingPickups] = useState<UpcomingPickup[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedPickup, setSelectedPickup] = useState<UpcomingPickup | null>(null);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [confirmationType, setConfirmationType] = useState<'pickup' | 'return'>('pickup');
  const [isExporting, setIsExporting] = useState(false);
  const [showExportOptions, setShowExportOptions] = useState(false);
  const [taskAlerts, setTaskAlerts] = useState<{
    today: Task[];
    week: Task[];
    overdue: Task[];
  }>({
    today: [],
    week: [],
    overdue: []
  });
  const [isLoadingTasks, setIsLoadingTasks] = useState(false);
  const [showTaskConfirmation, setShowTaskConfirmation] = useState<string | null>(null);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);

  useEffect(() => {
    loadDashboardData();
    loadTaskAlerts();
  }, []);

  const loadDashboardData = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const startDate = startOfMonth(subMonths(new Date(), 5));
      const endDate = endOfMonth(new Date());

      const [metricsData, revenueChartData, occupationChartData, returns, pickups] = await Promise.all([
        dashboardService.getMetrics(startDate, endDate),
        dashboardService.getRevenueChart(),
        dashboardService.getOccupationChart(),
        dashboardService.getTodayReturns(),
        dashboardService.getUpcomingPickups()
      ]);

      setMetrics(metricsData);
      setRevenueData(revenueChartData);
      setOccupationData(occupationChartData);
      setTodayReturns(returns);
      setUpcomingPickups(pickups);
    } catch (err) {
      setError('Erro ao carregar dados do dashboard');
      console.error('Error loading dashboard:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleConfirmPickup = async () => {
    if (!selectedPickup) return;

    try {
      await dashboardService.confirmPickup(selectedPickup.id);
      setShowConfirmation(false);
      setSelectedPickup(null);
      loadDashboardData();
    } catch (err) {
      setError('Erro ao confirmar retirada');
      console.error('Error confirming pickup:', err);
    }
  };

  const handleConfirmReturn = async () => {
    if (!selectedPickup) return;

    try {
      await dashboardService.confirmReturn(selectedPickup.id);
      setShowConfirmation(false);
      setSelectedPickup(null);
      loadDashboardData();
    } catch (err) {
      setError('Erro ao confirmar devolução');
      console.error('Error confirming return:', err);
    }
  };

  const handlePrintPickup = (pickup: UpcomingPickup) => {
    dashboardService.generatePickupDocument(pickup);
  };

  const loadTaskAlerts = async () => {
    setIsLoadingTasks(true);
    try {
      const alerts = await taskService.getTaskAlerts();
      setTaskAlerts(alerts);
    } catch (error) {
      console.error('Error loading task alerts:', error);
    } finally {
      setIsLoadingTasks(false);
    }
  };

  const handleCompleteTask = async (taskId: string) => {
    try {
      await taskService.completeTask(taskId);
      loadTaskAlerts();
    } catch (error) {
      console.error('Error completing task:', error);
    }
    setShowTaskConfirmation(null);
  };

  const getStatusIcon = (status: Task['status']) => {
    switch (status) {
      case 'completed':
        return <CheckCircle2 className="w-5 h-5 text-green-600" />;
      case 'in_progress':
        return <CircleDot className="w-5 h-5 text-yellow-600" />;
      default:
        return <Clock className="w-5 h-5 text-gray-600" />;
    }
  };

  const getPriorityColor = (priority: Task['priority']) => {
    switch (priority) {
      case 'high':
        return 'text-red-600 bg-red-50';
      case 'medium':
        return 'text-yellow-600 bg-yellow-50';
      case 'low':
        return 'text-green-600 bg-green-50';
      default:
        return 'text-gray-600 bg-gray-50';
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="flex items-center space-x-4">
          <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
          <p className="text-gray-600">Carregando dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <AlertTriangle className="w-12 h-12 text-red-600 mx-auto mb-4" />
          <p className="text-gray-600">{error}</p>
          <button
            onClick={loadDashboardData}
            className="mt-4 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center mx-auto"
          >
            <RefreshCw className="w-5 h-5 mr-2" />
            Tentar Novamente
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Dashboard</h1>
        <div className="relative">
          <button
            onClick={() => setShowExportOptions(!showExportOptions)}
            className="flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            disabled={isExporting}
          >
            {isExporting ? (
              <>
                <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                Exportando...
              </>
            ) : (
              <>
                <Download className="w-5 h-5 mr-2" />
                Exportar Relatório
              </>
            )}
          </button>
          {showExportOptions && (
            <div className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg z-10">
              <button
                onClick={() => handleExport('pdf')}
                className="w-full px-4 py-2 text-left hover:bg-gray-50 rounded-lg transition-colors"
              >
                <FileText className="w-5 h-5 inline mr-2" />
                PDF
              </button>
              <button
                onClick={() => handleExport('excel')}
                className="w-full px-4 py-2 text-left hover:bg-gray-50 rounded-lg transition-colors"
              >
                <FileText className="w-5 h-5 inline mr-2" />
                Excel
              </button>
              <button
                onClick={() => handleExport('csv')}
                className="w-full px-4 py-2 text-left hover:bg-gray-50 rounded-lg transition-colors"
              >
                <FileText className="w-5 h-5 inline mr-2" />
                CSV
              </button>
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* Devoluções de Hoje */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <Calendar className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Devoluções de Hoje</h2>
          </div>
          <div className="space-y-3">
            {todayReturns.length > 0 ? (
              todayReturns.map(return_ => (
                <div
                  key={return_.id}
                  className="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 cursor-pointer transition-colors"
                  onClick={() => {
                    setSelectedPickup(return_);
                    setConfirmationType('return');
                  }}
                >
                  <div className="flex justify-between items-center">
                    <div>
                      <p className="font-medium">{return_.client.name}</p>
                      <p className="text-sm text-gray-500">Pedido N° {return_.order_number}</p>
                    </div>
                    <span className="text-sm text-purple-600">{return_.return_time}</span>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-center text-gray-500 py-4">Nenhuma devolução para hoje</p>
            )}
          </div>
        </div>

        {/* Próximas Retiradas */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <Clock className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Próximas Retiradas</h2>
          </div>
          <div className="space-y-3">
            {upcomingPickups.length > 0 ? (
              upcomingPickups.map(pickup => (
                <div
                  key={pickup.id}
                  className="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 cursor-pointer transition-colors"
                  onClick={() => {
                    setSelectedPickup(pickup);
                    setConfirmationType('pickup');
                  }}
                >
                  <div className="flex justify-between items-center">
                    <div>
                      <p className="font-medium">{pickup.client.name}</p>
                      <p className="text-sm text-gray-500">Pedido N° {pickup.order_number}</p>
                    </div>
                    <span className="text-sm text-purple-600">
                      {new Date(pickup.pickup_date).toLocaleDateString() === new Date().toLocaleDateString()
                        ? 'Hoje'
                        : new Date(pickup.pickup_date).toLocaleDateString()} {pickup.pickup_time}
                    </span>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-center text-gray-500 py-4">Nenhuma retirada agendada</p>
            )}
          </div>
        </div>

        {/* Tarefas do Dia */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <CheckSquare className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Tarefas do Dia</h2>
          </div>
          <div className="space-y-3">
            {isLoadingTasks ? (
              <div className="flex justify-center py-4">
                <Loader2 className="w-6 h-6 animate-spin text-purple-600" />
              </div>
            ) : taskAlerts.today.length > 0 ? (
              taskAlerts.today.map(task => (
                <div
                  key={task.id}
                  className="p-3 bg-purple-50 rounded-lg cursor-pointer"
                  onClick={() => setSelectedTask(task)}
                >
                  <div className="flex justify-between items-start">
                    <div className="flex items-start space-x-3">
                      {getStatusIcon(task.status)}
                      <div>
                        <p className="font-medium">{task.title}</p>
                        <div className="flex items-center gap-2 mt-1">
                          <span className="text-sm text-gray-500">
                            <Calendar className="w-4 h-4 inline mr-1" />
                            {format(new Date(task.due_date), 'dd/MM/yyyy')}
                          </span>
                          <span className={`text-sm px-2 py-0.5 rounded-full ${getPriorityColor(task.priority)}`}>
                            {task.priority === 'high' ? 'Alta' : task.priority === 'medium' ? 'Média' : 'Baixa'}
                          </span>
                        </div>
                      </div>
                    </div>
                    <button
                      onClick={() => setShowTaskConfirmation(task.id)}
                      className="ml-2 p-1 text-green-600 hover:bg-green-100 rounded-lg transition-colors"
                      title="Marcar como concluída"
                    >
                      <CheckCircle2 className="w-5 h-5" />
                    </button>
                  </div>
                </div>
              ))
            ) : (
              <p className="text-center text-gray-500 py-4">Nenhuma tarefa para hoje</p>
            )}
          </div>
        </div>

        {/* Pedidos do Mês */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <TrendingUp className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Pedidos do Mês</h2>
          </div>
          {metrics && (
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Total de Pedidos</span>
                <span className="font-semibold">{metrics.totalOrders}</span>
              </div>
              <div className="flex justify-between">
                <span>Concluídos</span>
                <span className="font-semibold text-green-600">{metrics.completedOrders}</span>
              </div>
              <div className="flex justify-between">
                <span>Cancelados</span>
                <span className="font-semibold text-red-600">{metrics.canceledOrders}</span>
              </div>
            </div>
          )}
        </div>

        {/* Minhas Finanças */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <Wallet className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Minhas Finanças</h2>
          </div>
          {metrics && (
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Receitas</span>
                <span className="font-semibold text-green-600">
                  R$ {metrics.revenue.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Despesas</span>
                <span className="font-semibold text-red-600">
                  R$ {metrics.expenses.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Saldo</span>
                <span className="font-semibold">
                  R$ {metrics.balance.toFixed(2)}
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Métricas do Negócio */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center mb-4">
            <BarChart3 className="w-5 h-5 text-purple-600 mr-2" />
            <h2 className="text-lg font-semibold text-gray-800">Métricas do Negócio</h2>
          </div>
          {metrics && (
            <div className="space-y-2">
              <div className="flex justify-between">
                <span>Taxa de Ocupação</span>
                <span className="font-semibold">{metrics.occupationRate.toFixed(1)}%</span>
              </div>
              <div className="flex justify-between">
                <span>Clientes Recorrentes</span>
                <span className="font-semibold">{metrics.returningCustomers}</span>
              </div>
              <div className="flex justify-between">
                <span>Crescimento Mensal</span>
                <span className="font-semibold text-green-600">
                  {metrics.monthlyGrowth > 0 ? '+' : ''}{metrics.monthlyGrowth.toFixed(1)}%
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Gráficos */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        {/* Receitas */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Receitas</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={revenueData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Area
                  type="monotone"
                  dataKey="value"
                  stroke="#7c3aed"
                  fill="#7c3aed"
                  fillOpacity={0.1}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Taxa de Ocupação */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Taxa de Ocupação</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={occupationData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke="#7c3aed"
                  strokeWidth={2}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Modals */}
      {selectedPickup && (
        <UpcomingPickupModal
          pickup={selectedPickup}
          onClose={() => setSelectedPickup(null)}
          onPrint={handlePrintPickup}
          onConfirmPickup={() => {
            setConfirmationType(confirmationType);
            setShowConfirmation(true);
          }}
        />
      )}

      <ConfirmationModal
        isOpen={showConfirmation}
        onClose={() => setShowConfirmation(false)}
        onConfirm={confirmationType === 'pickup' ? handleConfirmPickup : handleConfirmReturn}
        title={confirmationType === 'pickup' ? 'Confirmar Retirada' : 'Confirmar Devolução'}
        message={
          confirmationType === 'pickup'
            ? 'Tem certeza que deseja confirmar esta retirada?'
            : 'Tem certeza que deseja confirmar esta devolução?'
        }
      />

      {/* Task Completion Confirmation Modal */}
      {showTaskConfirmation && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <div className="flex items-center mb-4 text-green-600">
              <CheckCircle2 className="w-6 h-6 mr-2" />
              <h3 className="text-lg font-semibold">Confirmar Conclusão</h3>
            </div>
            <p className="text-gray-600 mb-6">Tem certeza que deseja marcar esta tarefa como concluída?</p>
            <div className="flex justify-end gap-4">
              <button
                onClick={() => setShowTaskConfirmation(null)}
                className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
              >
                Cancelar
              </button>
              <button
                onClick={() => handleCompleteTask(showTaskConfirmation)}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                Confirmar
              </button>
            </div>
          </div>
        </div>
      )}

      {selectedTask && (
        <TaskDetailsModal
          task={selectedTask}
          onClose={() => setSelectedTask(null)}
          onComplete={(taskId) => {
            handleCompleteTask(taskId);
            setSelectedTask(null);
          }}
        />
      )}
    </div>
  );
};

export default Dashboard;