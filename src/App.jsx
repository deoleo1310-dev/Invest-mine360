import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ToastProvider } from './context/ToastContext'; // ← NUEVO
import { Layout } from './components/layout/Layout';
import Login from './pages/Login';
import AdminUsers from './pages/admin/Users';
import AdminWithdrawals from './pages/admin/Withdrawals';
import ClientDashboard from './pages/client/Dashboard';

// Protected Route Component
const ProtectedRoute = ({ children, role }) => {
  const { user, loading } = useAuth();
  
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-neutral-bg">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-neutral-gray">Cargando...</p>
        </div>
      </div>
    );
  }
  
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  
  if (role && user.role !== role) {
    return <Navigate to={user.role === 'admin' ? '/admin' : '/client'} replace />;
  }

  return <Layout>{children}</Layout>;
};

function App() {
  return (
    <ToastProvider> {/* ← ENVUELVE TODO CON ToastProvider */}
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            
            <Route path="/admin" element={
              <ProtectedRoute role="admin">
                <AdminUsers />
              </ProtectedRoute>
            } />
            <Route path="/admin/withdrawals" element={
              <ProtectedRoute role="admin">
                <AdminWithdrawals />
              </ProtectedRoute>
            } />

            <Route path="/client" element={
              <ProtectedRoute role="cliente">
                <ClientDashboard />
              </ProtectedRoute>
            } />
            
            <Route path="/" element={<Navigate to="/login" replace />} />
            <Route path="*" element={<Navigate to="/login" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ToastProvider>
  );
}

export default App;