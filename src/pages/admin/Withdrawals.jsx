import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Check, X, Loader2, DollarSign } from 'lucide-react';
import { useToast } from '../../context/ToastContext';
import { format, differenceInWeeks } from 'date-fns';
import { es } from 'date-fns/locale';

// ✅ FUNCIÓN CORREGIDA: Calcular balance ANTES del retiro actual
const calculateUserBalance = async (userId, excludeWithdrawalId = null) => {
  try {
    const { data: investment, error: invError } = await supabase
      .from('investments')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    if (invError || !investment) return null;

    const weeks = differenceInWeeks(new Date(), new Date(investment.created_at)) || 0;
    const weeklyGain = investment.inversion_actual * (investment.tasa_mensual / 4 / 100);
    const totalEarnings = weeklyGain * weeks;

    const { data: withdrawals, error: wdError } = await supabase
      .from('withdrawals')
      .select('id, monto, estado')
      .eq('user_id', userId);

    if (wdError) return null;

    const paidWithdrawals = withdrawals
      .filter(w => w.estado === 'pagado')
      .reduce((sum, w) => sum + Number(w.monto), 0);
    
    // ⚠️ CLAVE: Excluir el retiro que estamos evaluando
    const pendingWithdrawals = withdrawals
      .filter(w => w.estado === 'pendiente' && w.id !== excludeWithdrawalId)
      .reduce((sum, w) => sum + Number(w.monto), 0);

    return Math.max(0, totalEarnings - paidWithdrawals - pendingWithdrawals);
  } catch (error) {
  
    return null;
  }
};

export default function AdminWithdrawals() {
  const [withdrawals, setWithdrawals] = useState([]);
  const [userBalances, setUserBalances] = useState({});
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('pendiente');
  const [actionLoading, setActionLoading] = useState({});
  const { showSuccess, showError, showInfo } = useToast();

  const loadData = async () => {
    try {
      setLoading(true);

      const { data: withdrawalsData, error: wdError } = await supabase
        .from('withdrawals')
        .select('*, profiles(full_name, email)')
        .order('fecha_solicitud', { ascending: false });

      if (wdError) throw wdError;

      setWithdrawals(withdrawalsData);

      // ⚠️ NO pre-cargar balances aquí
      // Los calculamos on-demand cuando se intenta aprobar
      setUserBalances({});
    } catch (error) {
    
      showError('Error al cargar retiros');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleApprove = async (withdrawal) => {
    // ⚠️ IMPORTANTE: Excluir el retiro actual del cálculo
    const balance = userBalances[withdrawal.user_id] ?? 
                    await calculateUserBalance(withdrawal.user_id, withdrawal.id);
    
    if (balance === null) {
      showError('No se pudo verificar el balance del usuario');
      return;
    }

    const available = Number(balance);
    const requested = Number(withdrawal.monto);

    // ✅ VALIDACIÓN: Ahora SÍ tiene en cuenta solo OTROS pendientes
    if (requested > available) {
      showError(
        `❌ FONDOS INSUFICIENTES\n\n` +
        `Usuario: ${withdrawal.profiles?.full_name}\n` +
        `Solicitado: ${requested.toFixed(2)}\n` +
        `Disponible: ${available.toFixed(2)}\n` +
        `Faltante: ${(requested - available).toFixed(2)}`
      );
      return;
    }

 
    setActionLoading(prev => ({ ...prev, [withdrawal.id]: 'approving' }));

    try {
      const { error } = await supabase
        .from('withdrawals')
        .update({ 
          estado: 'pagado',
          fecha_procesado: new Date().toISOString()
        })
        .eq('id', withdrawal.id);

      if (error) throw error;

      showSuccess(`✅ Pago de ${requested.toFixed(2)} aprobado`);
      await loadData();
    } catch (error) {
     
      showError('Error al aprobar: ' + error.message);
    } finally {
      setActionLoading(prev => {
        const copy = { ...prev };
        delete copy[withdrawal.id];
        return copy;
      });
    }
  };

  const handleReject = async (withdrawal) => {
    if (
      showSuccess('Los fondos volverán a estar disponibles.')
    ) return;

    setActionLoading(prev => ({ ...prev, [withdrawal.id]: 'rejecting' }));

    try {
      const { error } = await supabase
        .from('withdrawals')
        .update({ 
          estado: 'rechazado',
          fecha_procesado: new Date().toISOString()
        })
        .eq('id', withdrawal.id);

      if (error) throw error;

      showInfo(`Retiro de $${withdrawal.monto} rechazado`);
      await loadData();
    } catch (error) {
   
      showError('Error: ' + error.message);
    } finally {
      setActionLoading(prev => {
        const copy = { ...prev };
        delete copy[withdrawal.id];
        return copy;
      });
    }
  };

  const filteredWithdrawals = filter === 'todos' 
    ? withdrawals 
    : withdrawals.filter(w => w.estado === filter);

  const tabs = [
    { id: 'pendiente', label: 'Pendientes', count: withdrawals.filter(w => w.estado === 'pendiente').length },
    { id: 'pagado', label: 'Pagados', count: withdrawals.filter(w => w.estado === 'pagado').length },
    { id: 'rechazado', label: 'Rechazados', count: withdrawals.filter(w => w.estado === 'rechazado').length },
    { id: 'todos', label: 'Todos', count: withdrawals.length },
  ];

  const getBadgeVariant = (status) => {
    if (status === 'pagado') return 'success';
    if (status === 'rechazado') return 'error';
    return 'warning';
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-primary-dark">Gestión de Retiros</h2>
        <div className="flex items-center gap-2 text-sm text-neutral-gray bg-white px-3 py-2 rounded-lg shadow-sm">
          <DollarSign size={16} />
          <span>{tabs[0].count} pendientes</span>
        </div>
      </div>

      <div className="flex gap-2 overflow-x-auto pb-2">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setFilter(tab.id)}
            className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
              filter === tab.id 
                ? 'bg-primary text-white' 
                : 'bg-white text-neutral-gray hover:bg-neutral-bg'
            }`}
          >
            {tab.label} ({tab.count})
          </button>
        ))}
      </div>

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
          
          {filteredWithdrawals.map((w) => {
            // ⚠️ NO mostrar alertas de balance aquí (calcularlo on-demand)
            // Solo mostrar el botón habilitado para pendientes

            return (
              <Card 
                key={w.id} 
                className="flex flex-col md:flex-row md:items-center justify-between gap-4"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-bold text-neutral-text">
                      {w.profiles?.full_name || 'Usuario'}
                    </h3>
                    <Badge variant={getBadgeVariant(w.estado)}>
                      {w.estado.toUpperCase()}
                    </Badge>
                  </div>
                  <p className="text-sm text-neutral-gray">{w.profiles?.email}</p>
                  <p className="text-xs text-neutral-gray mt-1">
                    {format(new Date(w.fecha_solicitud), "d 'de' MMMM, yyyy", { locale: es })}
                  </p>
                </div>

                <div className="flex items-center gap-3">
                  <span className="text-2xl font-bold text-primary-dark">
                    ${Number(w.monto).toLocaleString()}
                  </span>

                  {w.estado === 'pendiente' && (
                    <div className="flex gap-2">
                      <Button 
                        variant="success" 
                        className="p-2 rounded-full w-10 h-10" 
                        onClick={() => handleApprove(w)}
                        disabled={actionLoading[w.id]}
                        title="Aprobar"
                      >
                        {actionLoading[w.id] === 'approving' ? (
                          <Loader2 className="animate-spin" size={20} />
                        ) : (
                          <Check size={20} />
                        )}
                      </Button>
                      <Button 
                        variant="danger" 
                        className="p-2 rounded-full w-10 h-10"
                        onClick={() => handleReject(w)}
                        disabled={actionLoading[w.id]}
                        title="Rechazar"
                      >
                        {actionLoading[w.id] === 'rejecting' ? (
                          <Loader2 className="animate-spin" size={20} />
                        ) : (
                          <X size={20} />
                        )}
                      </Button>
                    </div>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}