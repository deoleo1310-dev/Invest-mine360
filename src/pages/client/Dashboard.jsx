import React, { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { TrendingUp, DollarSign, Clock, Loader2, Calendar, Plus } from 'lucide-react';
import { differenceInWeeks, format } from 'date-fns';
import { es } from 'date-fns/locale';

export default function ClientDashboard() {
  const { user } = useAuth();
  const [investment, setInvestment] = useState(null);
  const [withdrawals, setWithdrawals] = useState([]);
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [dataLoading, setDataLoading] = useState(true);
  const [message, setMessage] = useState(null);

  const loadData = async () => {
    if (!user) return;
    
    try {
      setDataLoading(true);
      console.log('📊 Cargando datos del cliente...');
      
      // Get Investment
      const { data: invData, error: invError } = await supabase
        .from('investments')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();
      
      if (invError) {
        console.error('Error cargando inversión:', invError);
      } else {
        console.log('✅ Inversión cargada:', invData);
        setInvestment(invData);
      }

      // Get Withdrawals
      const { data: wData, error: wError } = await supabase
        .from('withdrawals')
        .select('*')
        .eq('user_id', user.id)
        .order('fecha_solicitud', { ascending: false });
      
      if (wError) {
        console.error('Error cargando retiros:', wError);
      } else {
        setWithdrawals(wData || []);
      }
    } catch (error) {
      console.error("Error loading client data:", error);
    } finally {
      setDataLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [user]);

  // ✅ CÁLCULO SEMANAL DE GANANCIAS
  const calculateGain = () => {
    if (!investment || !investment.inversion_actual || !investment.tasa_mensual) {
      return { total: 0, weeks: 0, weeklyRate: 0, weeklyGain: 0 };
    }
    
    // Semanas transcurridas desde la creación de la inversión
    const weeks = differenceInWeeks(new Date(), new Date(investment.created_at)) || 0;
    
    // Tasa semanal = tasa mensual / 4
    const weeklyRate = (investment.tasa_mensual / 4);
    
    // Ganancia semanal = inversión * (tasa semanal / 100)
    const weeklyGain = investment.inversion_actual * (weeklyRate / 100);
    
    // Ganancia total acumulada = ganancia semanal * semanas
    const totalGain = weeklyGain * weeks;
    
    // Restar retiros pagados
    const paidWithdrawals = withdrawals
      .filter(w => w.estado === 'pagado')
      .reduce((acc, curr) => acc + Number(curr.monto), 0);
    
    const availableGain = Math.max(0, totalGain - paidWithdrawals);
    
    return {
      total: availableGain.toFixed(2),
      weeks,
      weeklyRate: weeklyRate.toFixed(2),
      weeklyGain: weeklyGain.toFixed(2)
    };
  };

  const gainInfo = calculateGain();
  const availableAmount = gainInfo.total;

  const handleInvestClick = () => {
    alert("Por favor envía el comprobante de tu pago al WhatsApp del administrador para procesar tu inversión adicional.");
    // Cambia este número por el WhatsApp del administrador
    window.open('https://wa.me/1234567890', '_blank');
  };

  const handleWithdrawRequest = async (e) => {
    e.preventDefault();
    setMessage(null);
    
    const amount = Number(withdrawAmount);
    
    if (amount < 50) {
      setMessage({ type: 'error', text: 'El retiro mínimo es de $50' });
      return;
    }
    
    if (amount > Number(availableAmount)) {
      setMessage({ type: 'error', text: `Fondos insuficientes. Disponible: $${availableAmount}` });
      return;
    }

    setLoading(true);
    try {
      const { error } = await supabase.from('withdrawals').insert({
        user_id: user.id,
        monto: amount,
        estado: 'pendiente'
      });

      if (error) throw error;
      
      setMessage({ type: 'success', text: '✅ Solicitud de retiro enviada. El administrador la revisará pronto.' });
      setWithdrawAmount('');
      loadData();
    } catch (error) {
      console.error(error);
      setMessage({ type: 'error', text: 'Error al procesar la solicitud' });
    } finally {
      setLoading(false);
    }
  };

  if (dataLoading) {
    return (
      <div className="flex justify-center items-center min-h-[60vh]">
        <div className="text-center">
          <Loader2 className="w-12 h-12 animate-spin text-primary mx-auto mb-4" />
          <p className="text-neutral-gray">Cargando tu inversión...</p>
        </div>
      </div>
    );
  }

  // Si no tiene inversión
  if (!investment) {
    return (
      <div className="max-w-2xl mx-auto text-center py-20">
        <div className="w-20 h-20 bg-primary-light rounded-full flex items-center justify-center mx-auto mb-6">
          <TrendingUp size={40} className="text-primary" />
        </div>
        <h2 className="text-2xl font-bold text-neutral-text mb-4">
          Aún no tienes una inversión activa
        </h2>
        <p className="text-neutral-gray mb-8">
          Contacta al administrador para configurar tu inversión inicial
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-8 max-w-5xl mx-auto">
      {/* Header Stats */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-primary-dark">Mi Inversión</h2>
          <div className="flex items-center gap-2 text-sm text-neutral-gray bg-white px-3 py-2 rounded-lg shadow-sm">
            <Calendar size={16} />
            <span>{gainInfo.weeks} semanas activas</span>
          </div>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Card 1: Inversión Actual */}
          <Card className="bg-gradient-to-br from-primary to-primary-dark text-white border-none">
            <p className="text-primary-light text-sm mb-1">Inversión Actual</p>
            <h3 className="text-3xl font-bold mb-2">
              ${investment.inversion_actual?.toLocaleString() || '0'}
            </h3>
            <div className="flex items-center gap-2 text-sm bg-white/10 w-fit px-2 py-1 rounded mt-2">
              <TrendingUp size={16} />
              <span>{gainInfo.weeklyRate}% Semanal</span>
            </div>
            <p className="text-xs text-white/70 mt-2">
              ({investment.tasa_mensual}% mensual)
            </p>
          </Card>

          {/* Card 2: Ganancia Semanal */}
          <Card className="bg-gradient-to-br from-green-500 to-green-700 text-white border-none">
            <p className="text-green-100 text-sm mb-1">Ganancia por Semana</p>
            <h3 className="text-3xl font-bold mb-2">
              ${gainInfo.weeklyGain}
            </h3>
            <p className="text-xs text-white/80">
              Calculado automáticamente cada semana
            </p>
          </Card>

          {/* Card 3: Total Disponible */}
          <Card className="border-2 border-status-success">
            <p className="text-neutral-gray text-sm mb-1">💰 Disponible para Retiro</p>
            <h3 className="text-3xl font-bold text-status-success mb-2">
              ${availableAmount}
            </h3>
            <p className="text-xs text-neutral-gray">
              Acumulado en {gainInfo.weeks} semanas
            </p>
          </Card>
        </div>

        {/* Botón de Inversión Adicional */}
        <Card className="mt-4 bg-primary-light/20 border-primary-light">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div>
              <h4 className="font-bold text-primary-dark mb-1">
                ¿Quieres aumentar tus ganancias?
              </h4>
              <p className="text-sm text-neutral-gray">
                Agrega más capital a tu inversión
              </p>
            </div>
            <Button onClick={handleInvestClick} className="w-full sm:w-auto">
              <Plus size={18} /> Invertir Más
            </Button>
          </div>
        </Card>
      </section>

      {/* Withdraw Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Request Form */}
        <section className="lg:col-span-1">
          <Card className="bg-gradient-to-br from-blue-50 to-indigo-50 border-primary-light/50">
            <h3 className="font-bold text-primary-dark mb-4 flex items-center gap-2">
              <DollarSign size={20} /> Solicitar Retiro
            </h3>
            
            <form onSubmit={handleWithdrawRequest} className="space-y-4">
              <div className="bg-white p-4 rounded-lg border border-primary-light/50 shadow-sm">
                <p className="text-xs text-neutral-gray mb-1">Disponible</p>
                <p className="text-2xl font-bold text-status-success">
                  ${availableAmount}
                </p>
              </div>

              <Input 
                type="number"
                step="0.01"
                label="Monto a Retirar"
                placeholder="Mínimo $50"
                value={withdrawAmount}
                onChange={e => setWithdrawAmount(e.target.value)}
                min="50"
                max={availableAmount}
              />
              
              {message && (
                <div className={`p-3 rounded-lg text-sm ${
                  message.type === 'error' 
                    ? 'bg-status-error/10 text-status-error border border-status-error/20' 
                    : 'bg-status-success/10 text-status-success border border-status-success/20'
                }`}>
                  {message.text}
                </div>
              )}

              <Button 
                type="submit" 
                variant="success" 
                className="w-full" 
                disabled={loading || Number(availableAmount) < 50}
              >
                {loading ? (
                  <>
                    <Loader2 className="animate-spin" size={18} />
                    <span>Procesando...</span>
                  </>
                ) : (
                  'Confirmar Solicitud'
                )}
              </Button>
              
              {Number(availableAmount) < 50 && (
                <p className="text-xs text-neutral-gray text-center">
                  Necesitas al menos $50 para retirar
                </p>
              )}
            </form>
          </Card>
        </section>

        {/* History */}
        <section className="lg:col-span-2">
          <h3 className="font-bold text-neutral-text mb-4 flex items-center gap-2">
            <Clock size={20} /> Historial de Retiros
          </h3>
          
          <div className="space-y-3">
            {withdrawals.length === 0 ? (
              <Card className="text-center py-10 border-dashed">
                <Clock size={40} className="mx-auto text-neutral-gray mb-3" />
                <p className="text-neutral-gray">No tienes retiros registrados aún</p>
              </Card>
            ) : (
              withdrawals.map((w) => (
                <Card key={w.id} className="flex items-center justify-between hover:shadow-md transition-shadow">
                  <div>
                    <p className="font-bold text-neutral-text">Retiro de ganancia</p>
                    <p className="text-xs text-neutral-gray">
                      {format(new Date(w.fecha_solicitud), "d 'de' MMMM, yyyy", { locale: es })}
                    </p>
                  </div>
                  <div className="text-right">
                    <span className="block font-bold text-xl mb-1">${Number(w.monto).toLocaleString()}</span>
                    <Badge 
                      variant={
                        w.estado === 'pagado' ? 'success' : 
                        w.estado === 'rechazado' ? 'error' : 
                        'warning'
                      }
                    >
                      {w.estado === 'pagado' ? '✓ Pagado' : 
                       w.estado === 'rechazado' ? '✗ Rechazado' : 
                       '⏳ Pendiente'}
                    </Badge>
                  </div>
                </Card>
              ))
            )}
          </div>
        </section>
      </div>
    </div>
  );
}