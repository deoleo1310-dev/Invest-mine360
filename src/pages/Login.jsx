import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import { TrendingUp, Loader2 } from 'lucide-react';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { useToast } from '../context/ToastContext';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { login, user, loading: authLoading } = useAuth();
  const navigate = useNavigate();
  const { showError, showSuccess } = useToast();

  useEffect(() => {
    if (user && user.role) {
      const destination = user.role === 'admin' ? '/admin' : '/client';
      navigate(destination, { replace: true });
    }
  }, [user, navigate]);

  const handleSubmit = async (e) => {
  e.preventDefault();
  setLoading(true);
  
  try {
    const data = await login(email, password);
    
    if (!data.session || !data.user) {
      throw new Error('No se pudo iniciar sesión');
    }
    
  
  } catch (err) {
    console.error('❌ Error en handleSubmit:', err);
    showError(err.message || 'Email o contraseña incorrectos');
    setLoading(false);
  }
};

  if (authLoading) {
    return (
      <div className="min-h-screen bg-neutral-bg flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-12 h-12 animate-spin text-primary mx-auto mb-4" />
          <p className="text-neutral-gray">Verificando sesión...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-neutral-bg flex flex-col items-center justify-center p-4">
      {/* Logo y título superior */}
      <div className="text-center mb-8">
        <div className="w-20 h-20 bg-primary rounded-3xl flex items-center justify-center text-white shadow-lg mx-auto mb-4">
          <TrendingUp size={40} strokeWidth={2.5} />
        </div>
        <h1 className="text-3xl font-bold text-neutral-text mb-2">Mine360pr</h1>
        <p className="text-neutral-gray">Tu plataforma de inversiones</p>
      </div>

      {/* Card de Login */}
      <div className="w-full max-w-md bg-white rounded-2xl shadow-card p-8">
        <h2 className="text-2xl font-bold text-neutral-text mb-6">Iniciar Sesión</h2>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-neutral-text mb-2">
              Usuario
            </label>
            <input
              type="email"
              placeholder="Nombre de usuario o email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              className="w-full px-4 py-3 rounded-lg border border-neutral-border bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all placeholder:text-neutral-gray/50"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-neutral-text mb-2">
              Contraseña
            </label>
            <input
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              className="w-full px-4 py-3 rounded-lg border border-neutral-border bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
            />
          </div>

        

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-primary hover:bg-primary-dark text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <Loader2 className="animate-spin" size={20} />
                <span>Verificando...</span>
              </>
            ) : (
              'Ingresar'
            )}
          </button>
        </form>
      </div>

      {/* Footer */}
      <footer className="mt-8 text-neutral-gray text-sm">
        © 2025 Mine360pr. Todos los derechos reservados.
      </footer>
    </div>
  );
}