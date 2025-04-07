import React from 'react';
import { X, Calendar, Clock, User, AlertCircle, MessageSquare } from 'lucide-react';
import { Task } from '../types/database';
import { format } from 'date-fns';

interface TaskDetailsModalProps {
  task: Task;
  onClose: () => void;
  onComplete: (taskId: string) => void;
}

const TaskDetailsModal: React.FC<TaskDetailsModalProps> = ({ task, onClose, onComplete }) => {
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

  const getStatusColor = (status: Task['status']) => {
    switch (status) {
      case 'completed':
        return 'text-green-600 bg-green-50';
      case 'in_progress':
        return 'text-yellow-600 bg-yellow-50';
      default:
        return 'text-gray-600 bg-gray-50';
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl mx-4">
        {/* Header */}
        <div className="flex justify-between items-center p-6 border-b">
          <h2 className="text-xl font-semibold">{task.title}</h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          <div className="space-y-6">
            {/* Description */}
            {task.description && (
              <div>
                <h3 className="text-sm font-medium text-gray-700 mb-2">Descrição</h3>
                <p className="text-gray-600">{task.description}</p>
              </div>
            )}

            {/* Details Grid */}
            <div className="grid grid-cols-2 gap-4">
              {/* Created At */}
              <div>
                <div className="flex items-center text-sm text-gray-600">
                  <Clock className="w-4 h-4 mr-2" />
                  <span>Criado em</span>
                </div>
                <p className="mt-1 font-medium">
                  {format(new Date(task.created_at), 'dd/MM/yyyy HH:mm')}
                </p>
              </div>

              {/* Due Date */}
              <div>
                <div className="flex items-center text-sm text-gray-600">
                  <Calendar className="w-4 h-4 mr-2" />
                  <span>Vencimento</span>
                </div>
                <p className="mt-1 font-medium">
                  {format(new Date(task.due_date), 'dd/MM/yyyy')}
                </p>
              </div>

              {/* Assigned To */}
              <div>
                <div className="flex items-center text-sm text-gray-600">
                  <User className="w-4 h-4 mr-2" />
                  <span>Responsável</span>
                </div>
                <p className="mt-1 font-medium">
                  {task.assigned_to || 'Não atribuído'}
                </p>
              </div>

              {/* Priority */}
              <div>
                <div className="flex items-center text-sm text-gray-600">
                  <AlertCircle className="w-4 h-4 mr-2" />
                  <span>Prioridade</span>
                </div>
                <p className={`mt-1 inline-flex px-2 py-1 rounded-full text-sm ${getPriorityColor(task.priority)}`}>
                  {task.priority === 'high' ? 'Alta' : task.priority === 'medium' ? 'Média' : 'Baixa'}
                </p>
              </div>
            </div>

            {/* Status */}
            <div>
              <h3 className="text-sm font-medium text-gray-700 mb-2">Status</h3>
              <p className={`inline-flex px-2 py-1 rounded-full text-sm ${getStatusColor(task.status)}`}>
                {task.status === 'completed' ? 'Concluída' : 
                 task.status === 'in_progress' ? 'Em Andamento' : 
                 'Pendente'}
              </p>
            </div>

            {/* Comments Section */}
            <div>
              <div className="flex items-center text-sm text-gray-600 mb-2">
                <MessageSquare className="w-4 h-4 mr-2" />
                <span>Comentários</span>
              </div>
              <div className="bg-gray-50 p-4 rounded-lg">
                <p className="text-gray-500 text-sm">Nenhum comentário ainda.</p>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-4 p-6 border-t bg-gray-50 rounded-b-lg">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
          >
            Fechar
          </button>
          {task.status !== 'completed' && (
            <button
              onClick={() => onComplete(task.id)}
              className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              Marcar como Concluída
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default TaskDetailsModal;