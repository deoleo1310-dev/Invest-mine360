import React, { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabaseClient';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { TrendingUp, DollarSign, Clock, Loader2 } from 'lucide-react';
import { differenceInMonths } from 'date-fns';

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
        // Get Investment
        const { data: invData } = await supabase
            .from('investments')
            .select()
            .eq('user_id', user.id)
            .maybeSingle(); // maybeSingle evita error si no hay datos
        
        setInvestment(invData);

        // Get Withdrawals
        const { data: wData } = await supabase
            .from('withdrawals')
            .select()
            .eq('user_id', user.id)
            .order('fecha_solicitud', { ascending: false });
            
        setWithdrawals(wData || []);
    } catch (error) {
        console.error("Error loading client data:", error);
    } finally {
        setDataLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [user]);

  const calculateGain = () => {
    if (!investment) return 0;
    const months = differenceInMonths(new Date(), new Date(investment.created_at)) || 1;
    const totalGenerated = investment.inversion_actual * (investment.tasa_mensual / 100) * months;
    
    const paidWithdrawals = withdrawals
      .filter(w => w.estado === 'pagado')
      .reduce((acc, curr) => acc + curr.monto, 0);
      
    return Math.max(0, totalGenerated - paidWithdrawals).toFixed(2);
  };

  const availableAmount = calculateGain();

  const handleInvestClick = () => {
    alert("Por favor envía el comprobante de tu pago al WhatsApp del administrador para procesar tu inversión.");
    window.open('https://paypal.me/admin_investpro', '_blank');
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
      setMessage({ type: 'error', text: 'Fondos insuficientes' });
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
        
        setMessage({ type: 'success', text: 'Solicitud de retiro enviada con éxito' });
        setWithdrawAmount('');
        loadData();
    } catch (error) {
        console.error(error);
        setMessage({ type: 'error', text: 'Error al procesar la solicitud' });
    } finally {
        setLoading(false);
    }
  };

  if (dataLoading) return <div className="flex justify-center p-10"><Loader2 className="animate-spin text-primary" /></div>;

  return (
    <div className="space-y-8">
      {/* Header Stats */}
      <section>
        <h2 className="text-2xl font-bold text-primary-dark mb-4">Mi Inversión</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-gradient-to-br from-primary to-primary-dark text-white border-none">
            <p className="text-primary-light text-sm mb-1">Inversión Actual</p>
            <h3 className="text-3xl font-bold">${investment?.inversion_actual?.toLocaleString() || '0'}</h3>
            <div className="mt-4 flex items-center gap-2 text-sm bg-white/10 w-fit px-2 py-1 rounded">
              <TrendingUp size={16} />
              <span>Tasa: {investment?.tasa_mensual || 0}% Mensual</span>
            </div>
          </Card>

          <Card>
            <p className="text-neutral-gray text-sm mb-1">Ganancia Disponible</p>
            <h3 className="text-3xl font-bold text-status-success">${availableAmount}</h3>
            <p className="text-xs text-neutral-gray mt-2">Calculado en base a tu tasa y tiempo</p>
          </Card>

          <Card className="flex flex-col justify-center items-center text-center gap-3">
            <p className="text-sm text-neutral-gray">¿Quieres aumentar tus ganancias?</p>
            <Button onClick={handleInvestClick} className="w-full">
              Invertir Ahora
            </Button>
          </Card>
        </div>
      </section>

      {/* Withdraw Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Request Form */}
        <section className="lg:col-span-1">
          <Card className="bg-primary-light/30 border-primary-light h-full">
            <h3 className="font-bold text-primary-dark mb-4 flex items-center gap-2">
              <DollarSign size={20} /> Solicitar Retiro
            </h3>
            
            <form onSubmit={handleWithdrawRequest} className="space-y-4">
              <div className="bg-white p-3 rounded-lg border border-primary-light/50">
                <p className="text-xs text-neutral-gray mb-1">Disponible para retiro</p>
                <p className="text-xl font-bold text-primary">${availableAmount}</p>
              </div>

              <Input 
                type="number"
                label="Monto a Retirar"
                placeholder="Mínimo $50"
                value={withdrawAmount}
                onChange={e => setWithdrawAmount(e.target.value)}
                min="50"
                max={availableAmount}
              />
              
              {message && (
                <div className={`p-3 rounded-lg text-sm ${message.type === 'error' ? 'bg-status-error/10 text-status-error' : 'bg-status-success/10 text-status-success'}`}>
                  {message.text}
                </div>
              )}

              <Button type="submit" variant="success" className="w-full" disabled={loading || Number(availableAmount) < 50}>
                {loading ? 'Procesando...' : 'Confirmar Solicitud'}
              </Button>
            </form>
          </Card>
        </section>

        {/* History */}
        <section className="lg:col-span-2">
          <h3 className="font-bold text-neutral-text mb-4 flex items-center gap-2">
            <Clock size={20} /> Historial de Retiros
          </h3>
          
          <div className="space-y-3">
            {withdrawals.length === 0 && (
              <div className="text-center py-8 text-neutral-gray bg-white rounded-xl border border-dashed border-neutral-border">
                No tienes retiros registrados aún.
              </div>
            )}

            {withdrawals.map((w) => (
              <Card key={w.id} className="flex items-center justify-between p-4">
                <div>
                  <p className="font-bold text-neutral-text">Retiro de ganancia</p>
                  <p className="text-xs text-neutral-gray">{new Date(w.fecha_solicitud).toLocaleDateString()}</p>
                </div>
                <div className="text-right">
                  <span className="block font-bold text-lg">${w.monto}</span>
                  <Badge 
                    variant={w.estado === 'pagado' ? 'success' : w.estado === 'rechazado' ? 'error' : 'warning'}
                  >
                    {w.estado}
                  </Badge>
                </div>
              </Card>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
