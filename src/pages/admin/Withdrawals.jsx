import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Check, X, Loader2 } from 'lucide-react';
import { useToast } from '../../context/ToastContext';

export default function AdminWithdrawals() {
  const [withdrawals, setWithdrawals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('pendiente');
  const { showSuccess, showError } = useToast();

  const loadData = async () => {
    try {
      setLoading(true);
      // Join con profiles para obtener nombre del usuario
      const { data, error } = await supabase
        .from('withdrawals')
        .select('*, profiles(full_name, email)')
        .order('fecha_solicitud', { ascending: false });

      if (error) throw error;
      setWithdrawals(data);
    } catch (error) {
      console.error("Error loading withdrawals:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleAction = async (id, status) => {
  try {
    await supabase.from('withdrawals').update({ 
      estado: status,
      fecha_procesado: new Date().toISOString()
    }).eq('id', id);
    
    const statusText = status === 'pagado' ? 'aprobado' : 'rechazado';
    showSuccess(`Retiro ${statusText} exitosamente`);
    loadData();
  } catch (error) {
    console.error("Error updating withdrawal:", error);
    showError("Error al actualizar el estado");
  }
};

  const filteredWithdrawals = filter === 'todos' 
    ? withdrawals 
    : withdrawals.filter(w => w.estado === filter);

  const tabs = [
    { id: 'todos', label: 'Todos' },
    { id: 'pendiente', label: 'Pendientes' },
    { id: 'pagado', label: 'Pagados' },
    { id: 'rechazado', label: 'Rechazados' },
  ];

  const getBadgeVariant = (status) => {
    if (status === 'pagado') return 'success';
    if (status === 'rechazado') return 'error';
    return 'warning';
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-primary-dark">Gestión de Retiros</h2>

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
            {tab.label}
          </button>
        ))}
      </div>

      {loading ? (
          <div className="flex justify-center p-10"><Loader2 className="animate-spin text-primary" /></div>
      ) : (
        <div className="space-y-4">
            {filteredWithdrawals.length === 0 && (
            <p className="text-center text-neutral-gray py-8">No hay retiros en esta categoría.</p>
            )}
            
            {filteredWithdrawals.map((w) => (
            <Card key={w.id} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-bold text-neutral-text">{w.profiles?.full_name || 'Usuario desconocido'}</h3>
                    <Badge variant={getBadgeVariant(w.estado)}>{w.estado.toUpperCase()}</Badge>
                </div>
                <p className="text-sm text-neutral-gray">{w.profiles?.email}</p>
                <p className="text-xs text-neutral-gray mt-1">
                    Solicitado: {new Date(w.fecha_solicitud).toLocaleDateString()}
                </p>
                </div>

                <div className="flex items-center gap-4">
                <span className="text-2xl font-bold text-primary-dark">${w.monto}</span>
                
                {w.estado === 'pendiente' && (
                    <div className="flex gap-2">
                    <Button 
                        variant="success" 
                        className="p-2 rounded-full w-10 h-10" 
                        onClick={() => handleAction(w.id, 'pagado')}
                        title="Marcar Pagado"
                    >
                        <Check size={20} />
                    </Button>
                    <Button 
                        variant="danger" 
                        className="p-2 rounded-full w-10 h-10"
                        onClick={() => handleAction(w.id, 'rechazado')}
                        title="Rechazar"
                    >
                        <X size={20} />
                    </Button>
                    </div>
                )}
                </div>
            </Card>
            ))}
        </div>
      )}
    </div>
  );
}
