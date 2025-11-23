import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { createSecondaryClient } from '../../lib/adminAuthClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { Plus, Pencil, TrendingUp, Loader2 } from 'lucide-react';
import { differenceInMonths } from 'date-fns';

export default function AdminUsers() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  
  // Form State
  const [formData, setFormData] = useState({
    full_name: '',
    email: '',
    password: '',
    inversion_actual: '',
    tasa_mensual: '',
    add_investment: ''
  });

  const loadUsers = async () => {
    try {
      setLoading(true);
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('*, investments(*)')
        .eq('role', 'cliente');

      if (profilesError) throw profilesError;
      
      const formattedUsers = profiles.map(p => ({
        ...p,
        investment: p.investments?.[0] || null
      }));
      
      setUsers(formattedUsers);
    } catch (error) {
      console.error("Error cargando usuarios:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  const handleOpenModal = (user = null) => {
    setEditingUser(user);
    if (user) {
      setFormData({
        full_name: user.full_name,
        email: user.email,
        password: '', // No mostramos password existente
        inversion_actual: user.investment?.inversion_actual || 0,
        tasa_mensual: user.investment?.tasa_mensual || 0,
        add_investment: ''
      });
    } else {
      setFormData({
        full_name: '',
        email: '',
        password: '',
        inversion_actual: '',
        tasa_mensual: '',
        add_investment: ''
      });
    }
    setIsModalOpen(true);
  };

  const calculateGain = (investment) => {
    if (!investment) return 0;
    const months = differenceInMonths(new Date(), new Date(investment.created_at)) || 1;
    return (investment.inversion_actual * (investment.tasa_mensual / 100) * months).toFixed(2);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    
    try {
      if (editingUser) {
        // --- MODO EDICIÓN ---
        
        // 1. Actualizar Perfil
        await supabase.from('profiles')
          .update({ full_name: formData.full_name })
          .eq('id', editingUser.id);

        // 2. Actualizar Inversión
        let newInvestmentAmount = Number(formData.inversion_actual);
        if (formData.add_investment) {
          newInvestmentAmount += Number(formData.add_investment);
        }

        if (editingUser.investment) {
            await supabase.from('investments').update({
                inversion_actual: newInvestmentAmount,
                tasa_mensual: Number(formData.tasa_mensual)
            }).eq('id', editingUser.investment.id);
        } else {
            await supabase.from('investments').insert({
                user_id: editingUser.id,
                inversion_actual: newInvestmentAmount,
                tasa_mensual: Number(formData.tasa_mensual)
            });
        }

      } else {
        // --- MODO CREACIÓN (NUEVO USUARIO) ---
        
        if (!formData.password || formData.password.length < 6) {
            throw new Error("La contraseña es obligatoria y debe tener al menos 6 caracteres.");
        }

        // 1. Crear usuario en Auth usando cliente secundario (para no desloguear al admin)
        const tempClient = createSecondaryClient();
        const { data: authData, error: authError } = await tempClient.auth.signUp({
            email: formData.email,
            password: formData.password,
            options: {
                data: {
                    full_name: formData.full_name,
                    // role: 'cliente' // El trigger se encarga, o por defecto es cliente
                }
            }
        });

        if (authError) throw authError;
        if (!authData.user) throw new Error("No se pudo crear el usuario.");

        const newUserId = authData.user.id;

        // 2. Asegurar que el perfil existe (El trigger debería haberlo creado, pero actualizamos nombre por si acaso)
        // Esperamos un momento para que el trigger se ejecute
        await new Promise(r => setTimeout(r, 1000));

        const { error: updateError } = await supabase.from('profiles')
            .update({ full_name: formData.full_name, role: 'cliente' })
            .eq('id', newUserId);

        // Si el trigger falló o no existe, insertamos manualmente (fallback)
        if (updateError) {
             await supabase.from('profiles').upsert({
                id: newUserId,
                email: formData.email,
                full_name: formData.full_name,
                role: 'cliente'
             });
        }

        // 3. Crear Inversión Inicial
        const { error: invError } = await supabase.from('investments').insert({
            user_id: newUserId,
            inversion_actual: Number(formData.inversion_actual),
            tasa_mensual: Number(formData.tasa_mensual),
            ganancia_acumulada: 0
        });

        if (invError) throw invError;

        alert("Usuario creado con éxito. " + (authData.session ? "" : "Se ha enviado un correo de confirmación (si está habilitado)."));
      }

      setIsModalOpen(false);
      loadUsers();
    } catch (error) {
      console.error(error);
      alert(error.message || "Error al guardar");
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-primary-dark">Gestión de Usuarios</h2>
        <Button onClick={() => handleOpenModal()}>
          <Plus size={18} /> Nuevo
        </Button>
      </div>

      {loading ? (
        <div className="flex justify-center p-10"><Loader2 className="animate-spin text-primary" /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {users.map((user) => (
            <Card key={user.id} className="relative">
                <button 
                onClick={() => handleOpenModal(user)}
                className="absolute top-4 right-4 text-neutral-gray hover:text-primary p-2 hover:bg-neutral-bg rounded-full transition-colors"
                title="Editar usuario"
                >
                <Pencil size={18} />
                </button>
                
                <div className="pr-8">
                <h3 className="text-lg font-bold text-neutral-text">{user.full_name}</h3>
                <p className="text-sm text-neutral-gray mb-4">{user.email}</p>
                
                <div className="flex flex-wrap gap-2 mb-4">
                    <Badge variant="primary">Inv: ${user.investment?.inversion_actual?.toLocaleString() || 0}</Badge>
                    <Badge variant="success">Tasa: {user.investment?.tasa_mensual || 0}%</Badge>
                </div>
                
                <div className="flex items-center gap-2 text-status-success font-medium bg-status-success/5 p-2 rounded-lg">
                    <TrendingUp size={16} />
                    <span>Ganancia est: ${calculateGain(user.investment)}</span>
                </div>
                </div>
            </Card>
            ))}
        </div>
      )}

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingUser ? "Editar Usuario" : "Nuevo Usuario"}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input 
            label="Nombre Completo"
            value={formData.full_name}
            onChange={e => setFormData({...formData, full_name: e.target.value})}
            required
          />
          <Input 
            label="Correo Electrónico"
            type="email"
            value={formData.email}
            onChange={e => setFormData({...formData, email: e.target.value})}
            required
            disabled={!!editingUser} // No permitir cambiar email en edición simple
          />
          
          {!editingUser && (
             <Input 
                label="Contraseña"
                type="password"
                value={formData.password}
                onChange={e => setFormData({...formData, password: e.target.value})}
                required
                placeholder="Mínimo 6 caracteres"
              />
          )}
          
          <div className="grid grid-cols-2 gap-4">
             <Input 
                label="Inversión Actual ($)"
                type="number"
                value={formData.inversion_actual}
                onChange={e => setFormData({...formData, inversion_actual: e.target.value})}
                disabled={!!editingUser} 
                required
              />
              <Input 
                label="Tasa Mensual (%)"
                type="number"
                step="0.01"
                value={formData.tasa_mensual}
                onChange={e => setFormData({...formData, tasa_mensual: e.target.value})}
                required
              />
          </div>

          {editingUser && (
            <div className="bg-primary-light/30 p-3 rounded-lg border border-primary-light">
               <label className="text-sm font-medium text-primary-dark block mb-2">Aumentar Inversión</label>
               <div className="flex gap-2">
                 <Input 
                    type="number" 
                    placeholder="Monto a agregar" 
                    className="flex-1"
                    value={formData.add_investment}
                    onChange={e => setFormData({...formData, add_investment: e.target.value})}
                 />
                 <Button type="button" variant="success" disabled={!formData.add_investment}>
                   <Plus size={16} />
                 </Button>
               </div>
            </div>
          )}

          <Button type="submit" className="w-full mt-4" disabled={actionLoading}>
            {actionLoading ? <Loader2 className="animate-spin" /> : 'Guardar'}
          </Button>
        </form>
      </Modal>
    </div>
  );
}
