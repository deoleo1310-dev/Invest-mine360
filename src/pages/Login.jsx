import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import { PieChart, Loader2 } from 'lucide-react';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { user } = await login(email, password);
      // Redirección basada en el rol obtenido del perfil
      // Nota: user.role viene del join con la tabla profiles en AuthContext
      if (user?.role === 'admin') navigate('/admin');
      else navigate('/client');
    } catch (err) {
      console.error(err);
      setError('Credenciales inválidas o error de conexión');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-light to-[#F7F9FC] flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-card p-8">
        <div className="flex flex-col items-center mb-8">
          <div className="w-14 h-14 bg-primary rounded-full flex items-center justify-center text-white shadow-lg mb-4">
            <PieChart size={28} />
          </div>
          <h1 className="text-2xl font-bold text-neutral-text">Iniciar Sesión</h1>
          <p className="text-neutral-gray mt-1">Bienvenido a InvestPro</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Input 
            label="Correo Electrónico"
            type="email"
            placeholder="tu@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <Input 
            label="Contraseña"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          {error && (
            <div className="p-3 bg-status-error/10 text-status-error text-sm rounded-lg">
              {error}
            </div>
          )}

          <Button type="submit" className="w-full py-3 text-lg" disabled={loading}>
            {loading ? <Loader2 className="animate-spin" /> : 'Ingresar'}
          </Button>
        </form>
      </div>
      
      <footer className="mt-8 text-neutral-gray text-sm">
        © 2025 InvestPro. Todos los derechos reservados.
      </footer>
    </div>
  );
}
