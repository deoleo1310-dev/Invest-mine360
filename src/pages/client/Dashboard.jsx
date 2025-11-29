import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { TrendingUp, DollarSign, Clock, Loader2, Calendar, Plus } from 'lucide-react';
import { differenceInWeeks, format } from 'date-fns';
import { es } from 'date-fns/locale';
import { useToast } from '../../context/ToastContext';

// ============================================
// CACHÉ MEJORADO CON REQUEST DEDUPLICATION
// ============================================
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

  // Previene múltiples llamadas simultáneas al mismo recurso
  async getOrFetch(key, fetchFn) {
    // Si hay datos en caché y son válidos, retornarlos
    const cached = this.get(key);
    if (cached) {
      console.log('✅ Caché encontrado para:', key);
      return cached;
    }

    // Si ya hay una petición en curso, esperar por ella
    if (this.pendingRequests.has(key)) {
      console.log('Esperando la petición pendiente para:', key);
      return this.pendingRequests.get(key);
    }

    // Crear nueva petición
    console.log('🔄 Obteniendo datos actualizados para:', key);
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
    console.log('Caché invalidada para:', key);
  }

  clear() {
    this.cache.clear();
    this.pendingRequests.clear();
    console.log('🗑️ Caché limpiada');
  }
}

// Instancia global del caché (30 segundos de TTL)
const clientCache = new DataCache(30000);

// ============================================
// FUNCIÓN AUXILIAR: Calcular Ganancias (Memoizable)
// ============================================
const calculateGain = (investment, withdrawals) => {
  if (!investment?.inversion_actual || !investment?.tasa_mensual) {
    return { total: 0, weeks: 0, weeklyRate: 0, weeklyGain: 0 };
  }
  
  const weeks = differenceInWeeks(new Date(), new Date(investment.created_at)) || 0;
  const weeklyRate = investment.tasa_mensual / 4;
  const weeklyGain = investment.inversion_actual * (weeklyRate / 100);
  const totalGain = weeklyGain * weeks;
  
  const paidWithdrawals = (withdrawals || [])
    .filter(w => w.estado === 'pagado')
    .reduce((acc, curr) => acc + Number(curr.monto), 0);
  
  return {
    total: Math.max(0, totalGain - paidWithdrawals).toFixed(2),
    weeks,
    weeklyRate: weeklyRate.toFixed(2),
    weeklyGain: weeklyGain.toFixed(2)
  };
};

// ============================================
// COMPONENTE PRINCIPAL OPTIMIZADO
// ============================================
export default function ClientDashboard() {
  const { user } = useAuth();
  const { showSuccess, showError } = useToast();
  
  // Estados
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [investment, setInvestment] = useState(null);
  const [withdrawals, setWithdrawals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  
  // Refs para control de ciclo de vida y cancelación
  const isMountedRef = useRef(true);
  const abortControllerRef = useRef(null);

  // ============================================
  // FETCH OPTIMIZADO: Usa caché y deduplicación
  // ============================================
  const fetchClientData = useCallback(async (userId) => {
    // Cancela cualquier petición anterior en curso
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    abortControllerRef.current = new AbortController();

    // Usa el caché con deduplicación
    return clientCache.getOrFetch(userId, async () => {
      // Consultas en paralelo para máxima eficiencia
      const [invResult, wdResult] = await Promise.all([
        supabase
          .from('investments')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle(),
        
        supabase
          .from('withdrawals')
          .select('*')
          .eq('user_id', userId)
          .order('fecha_solicitud', { ascending: false })
      ]);

      // Manejo de errores sin bloquear la UI
      if (invResult.error) {
        console.error('⚠️ Error cargando inversión:', invResult.error);
      }
      if (wdResult.error) {
        console.error('⚠️ Error cargando retiros:', wdResult.error);
      }

      return {
        investment: invResult.data,
        withdrawals: wdResult.data || []
      };
    });
  }, []); // Sin dependencias = función estable

  // ============================================
  // EFECTO: Carga inicial de datos
  // ============================================
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
          console.log('✅ Datos cargados correctamente');
        }
      } catch (error) {
        if (mounted && error.name !== 'AbortError') {
          console.error('❌ Error al cargar datos:', error);
          showError('Error al cargar datos. Por favor, recarga la página.');
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    loadData();

    // Cleanup: previene actualizaciones después de desmontar
    return () => {
      mounted = false;
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, [user?.id, fetchClientData, showError]);

  // ============================================
  // MEMOIZACIÓN: Evita recalcular en cada render
  // ============================================
  const gainInfo = useMemo(() => 
    calculateGain(investment, withdrawals), 
    [investment, withdrawals]
  );

  // ============================================
  // HANDLER: Solicitar Retiro (con UI Optimista)
  // ============================================
  const handleWithdrawRequest = async (e) => {
    e.preventDefault();
    
    const amount = Number(withdrawAmount);

    // Validaciones
    if (amount < 50) {
      showError('El retiro mínimo es de $50');
      return;
    }
    
    if (amount > Number(gainInfo.total)) {
      showError(`Fondos insuficientes. Disponible: $${gainInfo.total}`);
      return;
    }

    setSubmitting(true);

    // UI Optimista: Actualiza la UI inmediatamente
    const optimisticWithdrawal = {
      id: 'temp-' + Date.now(),
      user_id: user.id,
      monto: amount,
      estado: 'pendiente',
      fecha_solicitud: new Date().toISOString()
    };

    setWithdrawals(prev => [optimisticWithdrawal, ...prev]);
    setWithdrawAmount('');

    try {
      console.log('💰 Solicitando retiro de $', amount);
      
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
      
      console.log('✅ Retiro creado exitosamente:', data.id);

      // Reemplaza el registro temporal con el real del servidor
      setWithdrawals(prev => 
        prev.map(w => w.id === optimisticWithdrawal.id ? data : w)
      );

      // Invalida el caché para forzar una actualización fresca en la próxima carga
      clientCache.invalidate(user.id);
      
      showSuccess('✅ Solicitud de retiro enviada exitosamente');
      
    } catch (error) {
      console.error('❌ Error al solicitar retiro:', error);
      
      // Revierte el cambio optimista en caso de error
      setWithdrawals(prev => 
        prev.filter(w => w.id !== optimisticWithdrawal.id)
      );
      
      showError('Error al procesar la solicitud: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  // ============================================
  // HANDLER: Invertir Más
  // ============================================
  const handleInvestClick = useCallback(() => {
    alert("Por favor envía el comprobante de tu pago al WhatsApp del administrador.");
    window.open('https://www.paypal.com/paypalme/admin_investpro', '_blank');
  }, []);

  // ============================================
  // RENDER: Estado de Carga
  // ============================================
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

  // ============================================
  // RENDER: Sin Inversión
  // ============================================
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

  // ============================================
  // RENDER: Dashboard Principal
  // ============================================
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

          <Card className="bg-gradient-to-br from-green-500 to-green-700 text-white border-none">
            <p className="text-green-100 text-sm mb-1">Ganancia por Semana</p>
            <h3 className="text-3xl font-bold mb-2">
              ${gainInfo.weeklyGain}
            </h3>
            <p className="text-xs text-white/80">
              Calculado automáticamente cada semana
            </p>
          </Card>

          <Card className="border-2 border-status-success">
            <p className="text-neutral-gray text-sm mb-1">💰 Disponible para Retiro</p>
            <h3 className="text-3xl font-bold text-status-success mb-2">
              ${gainInfo.total}
            </h3>
            <p className="text-xs text-neutral-gray">
              Acumulado en {gainInfo.weeks} semanas
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

      {/* Withdraw Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <section className="lg:col-span-1">
          <Card className="bg-gradient-to-br from-blue-50 to-indigo-50 border-primary-light/50">
            <h3 className="font-bold text-primary-dark mb-4 flex items-center gap-2">
              <DollarSign size={20} /> Solicitar Retiro
            </h3>
            
            <div className="space-y-4">
              <div className="bg-white p-4 rounded-lg border border-primary-light/50 shadow-sm">
                <p className="text-xs text-neutral-gray mb-1">Disponible</p>
                <p className="text-2xl font-bold text-status-success">
                  ${gainInfo.total}
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
                max={gainInfo.total}
                disabled={submitting}
              />
              
              <Button 
                onClick={handleWithdrawRequest}
                variant="success" 
                className="w-full" 
                disabled={submitting || Number(gainInfo.total) < 50}
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
              
              {Number(gainInfo.total) < 50 && (
                <p className="text-xs text-neutral-gray text-center">
                  Necesitas al menos $50 para retirar
                </p>
              )}
            </div>
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