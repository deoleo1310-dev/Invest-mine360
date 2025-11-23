import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Layout } from './components/layout/Layout';
import Login from './pages/Login';
import AdminUsers from './pages/admin/Users';
import AdminWithdrawals from './pages/admin/Withdrawals';
import ClientDashboard from './pages/client/Dashboard';

// Protected Route Components
const ProtectedRoute = ({ children, role }) => {
  const { user, loading } = useAuth();
  
  if (loading) return <div className="min-h-screen flex items-center justify-center">Cargando...</div>;
  
  if (!user) return <Navigate to="/login" />;
  
  if (role && user.role !== role) {
    return <Navigate to={user.role === 'admin' ? '/admin' : '/client'} />;
  }

  return <Layout>{children}</Layout>;
};

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          
          {/* Admin Routes */}
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

          {/* Client Routes */}
          <Route path="/client" element={
            <ProtectedRoute role="cliente">
              <ClientDashboard />
            </ProtectedRoute>
          } />
          <Route path="/client/withdrawals" element={
            <ProtectedRoute role="cliente">
              <ClientDashboard /> {/* Reusing dashboard as it contains history as per request */}
            </ProtectedRoute>
          } />

          <Route path="/" element={<Navigate to="/login" />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}


export default App;
