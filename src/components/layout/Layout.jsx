import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { LogOut, Users, DollarSign, PieChart, Menu } from 'lucide-react';
import { Link, useLocation, useNavigate } from 'react-router-dom';

export const Layout = ({ children }) => {
  const { user, logout, isAdmin } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  // Componente de navegación unificado
  const NavItem = ({ to, icon: Icon, label, isMobile = false }) => {
    const isActive = location.pathname === to;
    
    // Estilos base
    const baseClass = "flex items-center gap-2 px-3 py-2 rounded-lg transition-all duration-200";
    
    // Estilos condicionales (Mobile vs Desktop)
    const desktopActive = "bg-white/20 text-white font-semibold shadow-sm";
    const desktopInactive = "text-white/80 hover:bg-white/10 hover:text-white";
    
    const mobileActive = "text-primary font-bold flex-col gap-1 text-xs";
    const mobileInactive = "text-neutral-gray hover:text-primary flex-col gap-1 text-xs";

    if (isMobile) {
        return (
            <Link to={to} className={`flex items-center justify-center ${isActive ? mobileActive : mobileInactive}`}>
                <Icon size={24} />
                <span>{label}</span>
            </Link>
        );
    }

    return (
      <Link 
        to={to} 
        className={`${baseClass} ${isActive ? desktopActive : desktopInactive}`}
      >
        <Icon size={18} />
        <span className="text-sm">{label}</span>
      </Link>
    );
  };

  return (
    <div className="min-h-screen bg-neutral-bg pb-24 md:pb-0">
      {/* Header Azul (Visible en todas las pantallas) */}
      <header className="bg-primary shadow-md sticky top-0 z-30">
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          {/* Logo */}
          <div className="flex items-center gap-3">
             <div className="w-9 h-9 bg-white rounded-full flex items-center justify-center text-primary shadow-sm">
                <PieChart size={20} strokeWidth={2.5} />
             </div>
             <h1 className="text-xl font-bold text-white tracking-tight">InvestPro</h1>
          </div>
          
          {/* Desktop Navigation (Visible solo en MD+) */}
          <div className="hidden md:flex items-center gap-2 bg-primary-dark/20 p-1 rounded-xl">
             {isAdmin ? (
              <>
                <NavItem to="/admin" icon={Users} label="Usuarios" />
                <NavItem to="/admin/withdrawals" icon={DollarSign} label="Retiros" />
              </>
            ) : (
              <>
                <NavItem to="/client" icon={PieChart} label="Panel" />
                <NavItem to="/client/withdrawals" icon={DollarSign} label="Retiros" />
              </>
            )}
          </div>

          {/* User Info & Logout */}
          <div className="flex items-center gap-4">
            <div className="hidden sm:flex flex-col items-end text-white">
                <span className="text-sm font-medium leading-none">{user?.full_name}</span>
                <span className="text-xs opacity-70">{isAdmin ? 'Administrador' : 'Inversionista'}</span>
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

      {/* Mobile Bottom Nav (Visible solo en móviles) */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-border flex justify-around items-center p-3 z-40 shadow-[0_-4px_20px_rgba(0,0,0,0.05)] pb-safe">
        {isAdmin ? (
          <>
            <NavItem to="/admin" icon={Users} label="Usuarios" isMobile={true} />
            <NavItem to="/admin/withdrawals" icon={DollarSign} label="Retiros" isMobile={true} />
          </>
        ) : (
          <>
            <NavItem to="/client" icon={PieChart} label="Panel" isMobile={true} />
            <NavItem to="/client/withdrawals" icon={DollarSign} label="Retiros" isMobile={true} />
          </>
        )}
      </nav>
    </div>
  );
};
