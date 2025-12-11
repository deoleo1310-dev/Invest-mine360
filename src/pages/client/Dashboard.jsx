import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { TrendingUp, DollarSign, Clock, Loader2, Calendar, Plus, AlertTriangle, CreditCard } from 'lucide-react';
import { differenceInDays, format } from 'date-fns';
import { es } from 'date-fns/locale';
import { useToast } from '../../context/ToastContext';

class DataCache {
  constructor(ttl = 30000) {
    this.cache = new Map();
    this.pendingRequests = new Map();
    this.ttl = ttl;
  }

  get(key) {
    const cached = this.cache.get(key);
    if (!cached) return null;
    
    if (Date.now() - cached.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return cached.data;
  }

  set(key, data) {
    this.cache.set(key, { data, timestamp: Date.now() });
  }

  async getOrFetch(key, fetchFn) {
    const cached = this.get(key);
    if (cached) return cached;

    if (this.pendingRequests.has(key)) {
      return this.pendingRequests.get(key);
    }

    const promise = fetchFn()
      .then(data => {
        this.set(key, data);
        this.pendingRequests.delete(key);
        return data;
      })
      .catch(err => {
        this.pendingRequests.delete(key);
        throw err;
      });

    this.pendingRequests.set(key, promise);
    return promise;
  }

  invalidate(key) {
    this.cache.delete(key);
    this.pendingRequests.delete(key);
  }
}

const clientCache = new DataCache(30000);

export default function ClientDashboard() {
  const { user } = useAuth();
  const { showSuccess, showError } = useToast();
  
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [investment, setInvestment] = useState(null);
  const [withdrawals, setWithdrawals] = useState([]);
  const [availableBalance, setAvailableBalance] = useState(0);
  const [totalEarnings, setTotalEarnings] = useState(0);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  const fetchClientData = useCallback(async (userId) => {
    return clientCache.getOrFetch(userId, async () => {
      const { data, error } = await supabase
        .rpc('get_client_dashboard_data', { p_user_id: userId });

      if (error) throw error;

      return {
        investment: data.investment,
        withdrawals: data.withdrawals || [],
        availableBalance: data.available_balance,
        totalEarnings: data.total_earnings
      };
    });
  }, []);

  useEffect(() => {
    if (!user?.id) return;

    let mounted = true;

    const loadData = async () => {
      try {
        setLoading(true);
        const data = await fetchClientData(user.id);
        
        if (mounted) {
          setInvestment(data.investment);
          setWithdrawals(data.withdrawals);
          setAvailableBalance(data.availableBalance);
          setTotalEarnings(data.totalEarnings);
        }
      } catch (error) {
        console.error('Load error:', error);
        if (mounted) {
          showError('Error al cargar datos: ' + error.message);
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    loadData();

    return () => {
      mounted = false;
    };
  }, [user?.id, fetchClientData, showError]);

  const funds = useMemo(() => {
    if (!investment?.inversion_actual || !investment?.tasa_diaria) {
      return {
        days: 0,
        dailyRate: 0,
        dailyGain: 0,
        paidWithdrawals: 0,
        pendingWithdrawals: 0,
        faltante: 0
      };
    }
    
    const days = differenceInDays(new Date(), new Date(investment.created_at)) || 0;
    const dailyRate = investment.tasa_diaria;
    const dailyGain = investment.inversion_actual * (dailyRate / 100);
    
    const paidWithdrawals = (withdrawals || [])
      .filter(w => w.estado === 'pagado')
      .reduce((acc, curr) => acc + Number(curr.monto), 0);
    
    const pendingWithdrawals = (withdrawals || [])
      .filter(w => w.estado === 'pendiente')
      .reduce((acc, curr) => acc + Number(curr.monto), 0);
    
    // ✅ FALTANTE desde la inversión
    const faltante = Number(investment.pendiente || 0);
    
    return {
      days,
      dailyRate: dailyRate.toFixed(4),
      dailyGain: dailyGain.toFixed(2),
      paidWithdrawals: paidWithdrawals.toFixed(2),
      pendingWithdrawals: pendingWithdrawals.toFixed(2),
      faltante: faltante.toFixed(2)
    };
  }, [investment, withdrawals]);

  const handleWithdrawRequest = async (e) => {
    e.preventDefault();
    
    const amount = Number(withdrawAmount);
    const available = Number(availableBalance);

    if (amount < 50) {
      showError('El retiro mínimo es de $50');
      return;
    }
    
    if (amount > available) {
      showError(
        `Fondos insuficientes.\n\n` +
        `Disponible: $${available.toFixed(2)}\n` +
        (Number(funds.pendingWithdrawals) > 0 
          ? `(Tienes $${funds.pendingWithdrawals} en retiros pendientes)` 
          : '')
      );
      return;
    }

    setSubmitting(true);

    try {
      const { data, error } = await supabase
        .from('withdrawals')
        .insert({
          user_id: user.id,
          monto: amount,
          estado: 'pendiente'
        })
        .select()
        .single();

      if (error) throw error;

      setWithdrawals(prev => [data, ...prev]);
      setAvailableBalance(prev => prev - amount);
      setWithdrawAmount('');
      
      clientCache.invalidate(user.id);
      
      showSuccess(
        `✅ Retiro de $${amount} solicitado exitosamente\n` +
        `Nuevo balance disponible: $${(available - amount).toFixed(2)}`
      );
      
    } catch (error) {
      console.error('Withdraw error:', error);
      showError('Error al procesar la solicitud: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleInvestClick = useCallback(() => {
    alert("Por favor enviar el comprobante de pago al WhatsApp del administrador");
    window.open('https://www.paypal.com/paypalme/DevonBrantPierre2025', '_blank');
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-[60vh]">
        <div className="text-center">
          <Loader2 className="w-12 h-12 animate-spin text-primary mx-auto mb-4" />
          <p className="text-neutral-gray">Cargando tu inversión...</p>
        </div>
      </div>
    );
  }

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
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-primary-dark">Mi Inversión</h2>
          <div className="flex items-center gap-2 text-sm text-neutral-gray bg-white px-3 py-2 rounded-lg shadow-sm">
            <Calendar size={16} />
            <span>{funds.days} días activos</span>
          </div>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Card 1: Inversión */}
          <Card className="bg-gradient-to-br from-primary to-primary-dark text-white border-none">
            <p className="text-primary-light text-sm mb-1">Inversión Actual</p>
            <h3 className="text-3xl font-bold mb-2">
              ${investment.inversion_actual?.toLocaleString() || '0'}
            </h3>
            <div className="flex items-center gap-2 text-sm bg-white/10 w-fit px-2 py-1 rounded mt-2">
              <TrendingUp size={16} />
              <span>{funds.dailyRate}% Diaria</span>
            </div>
            
               {/* ✅ MOSTRAR FALTANTE */}
            {Number(funds.faltante) > 0 && (
              <div className="mt-3 flex items-center gap-2 bg-amber-400/20 text-amber-100 px-3 py-2 rounded-lg text-sm border border-amber-300/30">
                <CreditCard size={16} />
                <div>
                  <p className="text-xs font-medium">💳 Faltante</p>
                  <p className="text-lg font-bold">${funds.faltante}</p>
                </div>
              </div>
            )}
          </Card>

          {/* Card 2: Ganancia Diaria */}
          <Card className="bg-gradient-to-br from-green-500 to-green-700 text-white border-none">
            <p className="text-green-100 text-sm mb-1">Ganancia por Día</p>
            <h3 className="text-3xl font-bold mb-2">
              ${funds.dailyGain}
            </h3>
            <p className="text-xs text-white/80 mt-2">
              Total acumulado: ${Number(totalEarnings).toFixed(2)}
            </p>
          </Card>

          {/* Card 3: Disponible */}
          <Card className={`border-2 ${
            Number(funds.pendingWithdrawals) > 0 
              ? 'border-amber-400 bg-amber-50' 
              : 'border-status-success'
          }`}>
            <p className="text-neutral-gray text-sm mb-1">💰 Disponible para Retiro</p>
            <h3 className={`text-3xl font-bold mb-2 ${
              Number(funds.pendingWithdrawals) > 0 
                ? 'text-amber-600' 
                : 'text-status-success'
            }`}>
              ${Number(availableBalance).toFixed(2)}
            </h3>
            
            {Number(funds.pendingWithdrawals) > 0 && (
              <div className="flex items-start gap-2 mt-2 p-2 bg-amber-100 rounded-lg border border-amber-300">
                <AlertTriangle size={16} className="text-amber-600 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800">
                  <strong>${funds.pendingWithdrawals}</strong> en retiros pendientes
                </p>
              </div>
            )}
            
            <p className="text-xs text-neutral-gray mt-2">
              Retiros pagados: ${funds.paidWithdrawals}
            </p>
          </Card>
        </div>

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

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <section className="lg:col-span-1">
          <Card className="bg-gradient-to-br from-blue-50 to-indigo-50 border-primary-light/50">
            <h3 className="font-bold text-primary-dark mb-4 flex items-center gap-2">
              <DollarSign size={20} /> Solicitar Retiro
            </h3>
            
            <form onSubmit={handleWithdrawRequest} className="space-y-4">
              <div className="bg-white p-4 rounded-lg border border-primary-light/50 shadow-sm">
                <p className="text-xs text-neutral-gray mb-1">Disponible</p>
                <p className="text-2xl font-bold text-status-success">
                  ${Number(availableBalance).toFixed(2)}
                </p>
                {Number(funds.pendingWithdrawals) > 0 && (
                  <p className="text-xs text-amber-600 mt-1">
                    (${funds.pendingWithdrawals} reservados)
                  </p>
                )}
              </div>

              <Input 
                type="number"
                step="0.01"
                label="Monto a Retirar"
                placeholder="Mínimo $50"
                value={withdrawAmount}
                onChange={e => setWithdrawAmount(e.target.value)}
                min="50"
                max={availableBalance}
                disabled={submitting || Number(availableBalance) < 50}
              />
              
              <Button 
                type="submit"
                variant="success" 
                className="w-full" 
                disabled={submitting || Number(availableBalance) < 50}
              >
                {submitting ? (
                  <>
                    <Loader2 className="animate-spin" size={18} />
                    <span>Procesando...</span>
                  </>
                ) : (
                  'Confirmar Solicitud'
                )}
              </Button>
              
              {Number(availableBalance) < 50 && (
                <p className="text-xs text-neutral-gray text-center">
                  Necesitas al menos $50 para retirar
                </p>
              )}
            </form>
          </Card>
        </section>

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
                <Card key={w.id} className="hover:shadow-md transition-shadow">
                  <div className="flex items-center justify-between mb-2">
                    <div>
                      <p className="font-bold text-neutral-text">Retiro de ganancia</p>
                      <p className="text-xs text-neutral-gray">
                        {format(new Date(w.fecha_solicitud), "d 'de' MMMM, yyyy", { locale: es })}
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="block font-bold text-xl mb-1">
                        ${Number(w.monto).toLocaleString()}
                      </span>
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
                  </div>

                  {w.estado === 'rechazado' && w.comentario_rechazo && (
                    <div className="mt-3 bg-red-50 border border-red-200 rounded-lg p-3">
                      <p className="text-xs font-semibold text-red-900 mb-1">
                        Motivo del rechazo:
                      </p>
                      <p className="text-sm text-red-700">
                        {w.comentario_rechazo}
                      </p>
                    </div>
                  )}
                </Card>
              ))
            )}
          </div>
        </section>
      </div>
    </div>
  );
}