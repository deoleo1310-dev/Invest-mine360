import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { LogOut, Users, DollarSign, TrendingUp } from 'lucide-react';
import { Link, useLocation, useNavigate } from 'react-router-dom';

export const Layout = ({ children }) => {
  const { user, logout, isAdmin } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  // Componente de navegación para móvil
  const NavItem = ({ to, icon: Icon, label }) => {
    const isActive = location.pathname === to;
    
    return (
      <Link 
        to={to} 
        className={`flex flex-col items-center justify-center gap-1 py-2 px-3 rounded-lg transition-all ${
          isActive 
            ? 'text-primary font-bold' 
            : 'text-neutral-gray hover:text-primary'
        }`}
      >
        <Icon size={24} />
        <span className="text-xs">{label}</span>
      </Link>
    );
  };

  return (
    <div className="min-h-screen bg-neutral-bg pb-20">
      {/* Header Simple - Para todos los usuarios */}
      <header className="bg-primary shadow-md sticky top-0 z-30">
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          {/* Logo */}
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-white rounded-full flex items-center justify-center text-primary shadow-sm">
              <TrendingUp size={20} strokeWidth={2.5} />
            </div>
            <h1 className="text-xl font-bold text-white tracking-tight">Mine360pr</h1>
          </div>

          {/* User Info & Logout */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex flex-col items-end text-white">
              <span className="text-sm font-medium leading-none">{user?.full_name}</span>
              <span className="text-xs opacity-70">
                {isAdmin ? 'Administrador' : 'Inversionista'}
              </span>
            </div>
            <button 
              onClick={handleLogout} 
              className="p-2 text-white/80 hover:text-white hover:bg-white/10 rounded-full transition-colors" 
              title="Cerrar Sesión"
            >
              <LogOut size={20} />
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-6xl mx-auto p-4 md:p-6 animate-in fade-in duration-500">
        {children}
      </main>

      {/* Mobile Bottom Nav - Para TODOS (Admin y Cliente) */}
      {isAdmin ? (
        <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-border flex justify-around items-center py-2 px-4 z-40 shadow-[0_-4px_20px_rgba(0,0,0,0.08)]">
          <NavItem to="/admin" icon={Users} label="Usuarios" />
          <NavItem to="/admin/withdrawals" icon={DollarSign} label="Retiros" />
        </nav>
      ) : (
        <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-border flex justify-center items-center py-2 px-4 z-40 shadow-[0_-4px_20px_rgba(0,0,0,0.08)]">
          <div className="flex items-center gap-2 text-primary font-medium">
            <TrendingUp size={20} />
            <span className="text-sm">Mi Inversión</span>
          </div>
        </nav>
      )}
    </div>
  );
};