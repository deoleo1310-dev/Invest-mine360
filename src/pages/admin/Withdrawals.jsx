import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Check, X, Loader2, DollarSign, AlertTriangle, RefreshCw } from 'lucide-react';
import { useToast } from '../../context/ToastContext';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import { RejectModal } from '../../components/ui/RejectModal';

class WithdrawalCache {
  constructor(ttl = 300000) {
    this.cache = null;
    this.timestamp = null;
    this.ttl = ttl;
  }

  get() {
    if (!this.cache || Date.now() - this.timestamp > this.ttl) {
      return null;
    }
    return this.cache;
  }

  set(data) {
    this.cache = data;
    this.timestamp = Date.now();
  }

  invalidate() {
    this.cache = null;
    this.timestamp = null;
  }
}

const cache = new WithdrawalCache();

export default function AdminWithdrawals() {
  const [withdrawals, setWithdrawals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('pendiente');
  const [actionLoading, setActionLoading] = useState({});
  const { showSuccess, showError, showInfo } = useToast();
  const [rejectModalOpen, setRejectModalOpen] = useState(false);
  const [withdrawalToReject, setWithdrawalToReject] = useState(null);

  const loadData = async (useCache = true) => {
    try {
      setLoading(true);

      if (useCache) {
        const cached = cache.get();
        if (cached) {
          console.log('📦 Usando datos en caché');
          setWithdrawals(cached);
          setLoading(false);
          return;
        }
      }

      console.log('🔄 Cargando datos desde Supabase...');

      const { data, error } = await supabase
        .rpc('get_withdrawals_with_balances');

      if (error) {
        console.error('❌ Error en RPC:', error);
        throw error;
      }

      const transformed = data.map(w => ({
        id: w.withdrawal_id,
        user_id: w.user_id,
        monto: w.monto,
        estado: w.estado,
        fecha_solicitud: w.fecha_solicitud,
        available_balance: w.available_balance,
        comentario: w.comentario_rechazo,
        profiles: {
          full_name: w.user_name,
          email: w.user_email
        }
      }));

      cache.set(transformed);
      setWithdrawals(transformed);
    } catch (error) {
      console.error('❌ Load error:', error);
      showError('Error al cargar retiros: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData(true);

    const interval = setInterval(() => {
      console.log('🔄 Recarga automática...');
      loadData(false);
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  const handleRejectClick = (withdrawal) => {
    setWithdrawalToReject(withdrawal);
    setRejectModalOpen(true);
  };

  // ✅ CORREGIDO: Obtener balance desde la vista admin (excluye el retiro actual)
  const getLatestBalance = async (userId, withdrawalId) => {
    try {
      const { data, error } = await supabase
        .rpc('get_available_balance_for_admin', { 
          p_user_id: userId,
          p_withdrawal_id: withdrawalId 
        });

      if (error) throw error;

      return {
        availableBalance: data
      };
    } catch (error) {
      console.error('Error getting balance:', error);
      throw error;
    }
  };

  // ✅ MEJORADO: Validación en tiempo real antes de aprobar
  const handleApprove = async (withdrawal) => {
    setActionLoading(prev => ({ ...prev, [withdrawal.id]: 'checking' }));

    try {
      // ✅ PASO 1: Obtener balance actualizado (excluyendo este retiro)
      const latestBalance = await getLatestBalance(withdrawal.user_id, withdrawal.id);
      const available = Number(latestBalance.availableBalance);
      const requested = Number(withdrawal.monto);

      console.log('💰 Balance actualizado:', {
        available,
        requested,
        withdrawalId: withdrawal.id
      });

      // ✅ PASO 2: Validar con datos frescos
      if (requested > available) {
        showError(
          `❌ FONDOS INSUFICIENTES\n\n` +
          `Usuario: ${withdrawal.profiles?.full_name}\n` +
          `Ganancias generadas: $${latestBalance.totalEarnings.toFixed(2)}\n` +
          `Disponible actual: $${available.toFixed(2)}\n` +
          `Solicitado: $${requested.toFixed(2)}\n` +
          `Faltante: $${(requested - available).toFixed(2)}\n\n` +
          `💡 Sugerencia: Genera más ganancias o rechaza el retiro`
        );
        setActionLoading(prev => {
          const copy = { ...prev };
          delete copy[withdrawal.id];
          return copy;
        });
        return;
      }

      // ✅ PASO 3: Confirmar con el admin
      const confirmMsg = 
        `¿Aprobar retiro de $${requested.toFixed(2)}?\n\n` +
        `Usuario: ${withdrawal.profiles?.full_name}\n` +
        `Balance disponible: $${available.toFixed(2)}\n` +
        `Nuevo balance: $${(available - requested).toFixed(2)}`;

      if (!confirm(confirmMsg)) {
        setActionLoading(prev => {
          const copy = { ...prev };
          delete copy[withdrawal.id];
          return copy;
        });
        return;
      }

      // ✅ PASO 4: Aprobar (el trigger de BD hará la validación final)
      setActionLoading(prev => ({ ...prev, [withdrawal.id]: 'approving' }));

      const { error } = await supabase
        .from('withdrawals')
        .update({ 
          estado: 'pagado',
          fecha_procesado: new Date().toISOString()
        })
        .eq('id', withdrawal.id);

      if (error) {
        // ✅ Si el trigger rechazó, mostramos el error
        if (error.message.includes('FONDOS INSUFICIENTES')) {
          showError('⚠️ El retiro fue rechazado por fondos insuficientes (validación de BD)');
        } else {
          throw error;
        }
        return;
      }

      showSuccess(
        `✅ Pago aprobado exitosamente\n\n` +
        `Monto: $${requested.toFixed(2)}\n` +
        `Usuario: ${withdrawal.profiles?.full_name}`
      );
      
      cache.invalidate();
      await loadData(false);
    } catch (error) {
      console.error('Approve error:', error);
      showError('Error al aprobar: ' + error.message);
    } finally {
      setActionLoading(prev => {
        const copy = { ...prev };
        delete copy[withdrawal.id];
        return copy;
      });
    }
  };

  const handleRejectConfirm = async (comment) => {
    const withdrawal = withdrawalToReject;

    setActionLoading(prev => ({ ...prev, [withdrawal.id]: 'rejecting' }));

    try {
      const { error } = await supabase
        .from('withdrawals')
        .update({ 
          estado: 'rechazado',
          comentario_rechazo: comment,
          fecha_procesado: new Date().toISOString()
        })
        .eq('id', withdrawal.id);

      if (error) throw error;

      showInfo(`Retiro de $${withdrawal.monto} rechazado`);
      cache.invalidate();
      await loadData(false);
      
      setRejectModalOpen(false);
      setWithdrawalToReject(null);
    } catch (error) {
      console.error('Reject error:', error);
      showError('Error: ' + error.message);
    } finally {
      setActionLoading(prev => {
        const copy = { ...prev };
        delete copy[withdrawal.id];
        return copy;
      });
    }
  };

  const filteredWithdrawals = useMemo(() => {
    if (filter === 'todos') return withdrawals;
    return withdrawals.filter(w => w.estado === filter);
  }, [withdrawals, filter]);

  const counts = useMemo(() => ({
    pendiente: withdrawals.filter(w => w.estado === 'pendiente').length,
    pagado: withdrawals.filter(w => w.estado === 'pagado').length,
    rechazado: withdrawals.filter(w => w.estado === 'rechazado').length,
    todos: withdrawals.length
  }), [withdrawals]);

  const tabs = [
    { id: 'pendiente', label: 'Pendientes', count: counts.pendiente },
    { id: 'pagado', label: 'Pagados', count: counts.pagado },
    { id: 'rechazado', label: 'Rechazados', count: counts.rechazado },
    { id: 'todos', label: 'Todos', count: counts.todos },
  ];

  const getBadgeVariant = (status) => {
    if (status === 'pagado') return 'success';
    if (status === 'rechazado') return 'error';
    return 'warning';
  };

  return (
    <div className="space-y-6">

      {/* ENCABEZADO */}
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-primary-dark">Gestión de Retiros</h2>

        <div className="flex items-center gap-2">
          <button
            onClick={() => loadData(false)}
            className="flex items-center gap-2 text-sm text-neutral-gray bg-white px-3 py-2 rounded-lg shadow-sm hover:bg-neutral-bg transition-colors"
            title="Recargar datos"
          >
            <RefreshCw size={16} />
            <span className="hidden sm:inline">Actualizar</span>
          </button>
          
          <div className="flex items-center gap-2 text-sm text-neutral-gray bg-white px-3 py-2 rounded-lg shadow-sm">
            <DollarSign size={16} />
            <span>{counts.pendiente} pendientes</span>
          </div>
        </div>
      </div>

      {/* TABS */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setFilter(tab.id)}
            className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
              filter === tab.id 
                ? "bg-primary text-white" 
                : "bg-white text-neutral-gray hover:bg-neutral-bg"
            }`}
          >
            {tab.label} ({tab.count})
          </button>
        ))}
      </div>

      {/* LOADING */}
      {loading ? (
        <div className="flex justify-center p-10">
          <Loader2 className="animate-spin text-primary" size={40} />
        </div>
      ) : (
        <div className="space-y-4">

          {filteredWithdrawals.length === 0 && (
            <Card className="text-center py-10">
              <p className="text-neutral-gray">No hay retiros en esta categoría</p>
            </Card>
          )}

          {filteredWithdrawals.map((w) => (
            <Card 
              key={w.id} 
              className="flex flex-col md:flex-row md:items-center justify-between gap-4"
            >
              {/* INFORMACIÓN DEL USUARIO */}
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-bold text-neutral-text">
                    {w.profiles?.full_name || "Usuario"}
                  </h3>
                  <Badge variant={getBadgeVariant(w.estado)}>
                    {w.estado.toUpperCase()}
                  </Badge>
                </div>

                <p className="text-sm text-neutral-gray">{w.profiles?.email}</p>

                <p className="text-xs text-neutral-gray mt-1">
                  {format(new Date(w.fecha_solicitud), "d 'de' MMMM, yyyy", { locale: es })}
                </p>

                {/* INDICADOR DE BALANCE */}
                {w.estado === "pendiente" && (
                  <div className="mt-2 flex items-center gap-2 text-xs">
                    {Number(w.monto) > Number(w.available_balance) ? (
                      <div className="flex items-center gap-1 text-red-600 bg-red-50 px-2 py-1 rounded">
                        <AlertTriangle size={14} />
                        <span>Balance insuficiente: ${Number(w.available_balance).toFixed(2)}</span>
                      </div>
                    ) : (
                      <div className="text-green-600">
                        ✓ Balance disponible: ${Number(w.available_balance).toFixed(2)}
                      </div>
                    )}
                  </div>
                )}

                {/* COMENTARIO SI RECHAZADO */}
                {w.estado === "rechazado" && w.comentario && (
                  <div className="mt-3 bg-red-50 text-red-700 text-sm p-2 rounded">
                    <strong>Motivo del rechazo:</strong> {w.comentario}
                  </div>
                )}
              </div>

              {/* MONTO Y ACCIONES */}
              <div className="flex items-center gap-3">
                <span className="text-2xl font-bold text-primary-dark">
                  ${Number(w.monto).toLocaleString()}
                </span>

                {w.estado === "pendiente" && (
                  <div className="flex gap-2">

                    {/* APROBAR */}
                    <Button 
                      variant="success" 
                      className="p-2 rounded-full w-10 h-10" 
                      onClick={() => handleApprove(w)}
                      disabled={actionLoading[w.id]}
                      title="Aprobar (validará balance en tiempo real)"
                    >
                      {actionLoading[w.id] === "checking" ? (
                        <RefreshCw className="animate-spin" size={20} />
                      ) : actionLoading[w.id] === "approving" ? (
                        <Loader2 className="animate-spin" size={20} />
                      ) : (
                        <Check size={20} />
                      )}
                    </Button>

                    {/* RECHAZAR */}
                    <Button 
                      variant="danger" 
                      className="p-2 rounded-full w-10 h-10"
                      onClick={() => handleRejectClick(w)}
                      disabled={actionLoading[w.id]}
                      title="Rechazar"
                    >
                      {actionLoading[w.id] === "rejecting" ? (
                        <Loader2 className="animate-spin" size={20} />
                      ) : (
                        <X size={20} />
                      )}
                    </Button>

                  </div>
                )}
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* MODAL DE RECHAZO */}
      <RejectModal 
        isOpen={rejectModalOpen}
        onClose={() => {
          setRejectModalOpen(false);
          setWithdrawalToReject(null);
        }}
        onConfirm={handleRejectConfirm}
        withdrawal={withdrawalToReject}
      />
    </div>
  );
}