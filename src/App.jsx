import React, { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ToastProvider } from './context/ToastContext';
import { Loader2 } from 'lucide-react';
import { useSettingsStore } from './store/settingsStore';
import { useEffect } from 'react';


import { Layout } from './components/layout/Layout';


const Login = lazy(() => import('./pages/Login'));
const AdminUsers = lazy(() => import('./pages/admin/Users'));
const AdminWithdrawals = lazy(() => import('./pages/admin/Withdrawals'));
const AdminSettings = lazy(() => import('./pages/admin/Settings'));
const ClientDashboard = lazy(() => import('./pages/client/Dashboard'));


const PageLoader = () => (
  <div className="min-h-screen flex items-center justify-center bg-neutral-bg">
    <div className="text-center">
      <Loader2 className="w-12 h-12 animate-spin text-primary mx-auto mb-4" />
      <p className="text-neutral-gray font-medium">Cargando...</p>
    </div>
  </div>
);

// ✅ Protected Route Component (Optimizado)
const ProtectedRoute = ({ children, role }) => {
  const { user, loading } = useAuth();
  
  // Mientras carga autenticación
  if (loading) {
    return <PageLoader />;
  }
  
  // Si no está autenticado
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  
  // Si requiere un rol específico y no lo tiene
  if (role && user.role !== role) {
    return <Navigate to={user.role === 'admin' ? '/admin' : '/client'} replace />;
  }

  // Usuario válido, mostrar contenido
  return <Layout>{children}</Layout>;
};

function App() {
  const fetchSettings = useSettingsStore(state => state.fetchSettings);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  return (
    <ToastProvider>
      <AuthProvider>
        <BrowserRouter>
          <Suspense fallback={<PageLoader />}>
            <Routes>
              {/* ✅ Ruta pública - Login */}
              <Route path="/login" element={<Login />} />
              
              {/* ✅ Rutas de Admin */}
              <Route 
                path="/admin" 
                element={
                  <ProtectedRoute role="admin">
                    <AdminUsers />
                  </ProtectedRoute>
                } 
              />
              <Route 
                path="/admin/withdrawals" 
                element={
                  <ProtectedRoute role="admin">
                    <AdminWithdrawals />
                  </ProtectedRoute>
                } 
              />

              <Route 
                path="/admin/settings" 
                element={
                  <ProtectedRoute role="admin">
                    <AdminSettings />
                  </ProtectedRoute>
                } 
              />

              {/* ✅ Ruta de Cliente */}
              <Route 
                path="/client" 
                element={
                  <ProtectedRoute role="cliente">
                    <ClientDashboard />
                  </ProtectedRoute>
                } 
              />
              
              {/* ✅ Redirects */}
              <Route path="/" element={<Navigate to="/login" replace />} />
              <Route path="*" element={<Navigate to="/login" replace />} />
            </Routes>
          </Suspense>
        </BrowserRouter>
      </AuthProvider>
    </ToastProvider>
  );
}

export default App;