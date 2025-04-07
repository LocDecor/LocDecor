import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import Dashboard from '../pages/Dashboard';
import Clientes from '../pages/Clientes';
import Acervo from '../pages/Acervo';
import Pedidos from '../pages/Pedidos';
import Financeiro from '../pages/Financeiro';
import Tarefas from '../pages/Tarefas';
import Login from '../pages/Login';
import { PrivateRoute } from '../components/PrivateRoute';

const AppRoutes = () => {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/"
        element={
          <PrivateRoute>
            <Dashboard />
          </PrivateRoute>
        }
      />
      <Route
        path="/clientes"
        element={
          <PrivateRoute>
            <Clientes />
          </PrivateRoute>
        }
      />
      <Route
        path="/acervo"
        element={
          <PrivateRoute>
            <Acervo />
          </PrivateRoute>
        }
      />
      <Route
        path="/pedidos"
        element={
          <PrivateRoute>
            <Pedidos />
          </PrivateRoute>
        }
      />
      <Route
        path="/financeiro"
        element={
          <PrivateRoute>
            <Financeiro />
          </PrivateRoute>
        }
      />
      <Route
        path="/tarefas"
        element={
          <PrivateRoute>
            <Tarefas />
          </PrivateRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default AppRoutes;