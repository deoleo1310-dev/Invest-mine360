import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { createSecondaryClient } from '../../lib/adminAuthClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { Plus, Pencil, TrendingUp, Loader2, Eye, EyeOff, Lock, AlertCircle } from 'lucide-react';
import { differenceInWeeks } from 'date-fns';
import { useToast } from '../../context/ToastContext';

export default function AdminUsers() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const { showSuccess, showError } = useToast(); // Toast notificaticaciones
  
  const [formData, setFormData] = useState({
    full_name: '',
    email: '',
    password: '',
    confirmPassword: '', 
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
        .eq('role', 'cliente')
        .order('created_at', { ascending: false });

      if (profilesError) throw profilesError;
      
      const formattedUsers = profiles.map(p => ({
        ...p,
        investment: p.investments?.[0] || null
      }));
      
      console.log('👥 Usuarios cargados:', formattedUsers);
      setUsers(formattedUsers);
    } catch (error) {
      console.error("Error cargando usuarios:", error);
     showError("Error al cargar usuarios: " + error.message);
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
      password: '',              // ← Siempre vacío al editar
      confirmPassword: '',       // ← Siempre vacío al editar
      inversion_actual: user.investment?.inversion_actual || 0,
      tasa_mensual: user.investment?.tasa_mensual || 0,
      add_investment: ''
    });
  } else {
    setFormData({
      full_name: '',
      email: '',
      password: '',
      confirmPassword: '',
      inversion_actual: '',
      tasa_mensual: '',
      add_investment: ''
    });
  }
  setIsModalOpen(true);
};

  // ✅ CÁLCULO SEMANAL DE GANANCIAS
  const calculateGain = (investment) => {
    if (!investment || !investment.inversion_actual || !investment.tasa_mensual) {
      return 0;
    }
    
    // Calcular semanas transcurridas desde la creación
    const weeks = differenceInWeeks(new Date(), new Date(investment.created_at)) || 0;
    
    // Tasa semanal = tasa mensual / 4
    const weeklyRate = investment.tasa_mensual / 4;
    
    // Ganancia total = inversión * (tasa semanal / 100) * semanas
    const totalGain = investment.inversion_actual * (weeklyRate / 100) * weeks;
    
    return totalGain.toFixed(2);
  };
// Función para resetear contraseña usando Edge Function
const resetPassword = async (userId, newPassword) => {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session) {
      throw new Error('No hay sesión activa');
    }
    
    const response = await fetch(
      `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/admin-reset-password`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId,
          newPassword
        })
      }
    );

    const result = await response.json();

    if (!result.success) {
      throw new Error(result.error || 'Error al cambiar contraseña');
    }

    return result;
  } catch (error) {
    console.error('Error en resetPassword:', error);
    throw error;
  }
};
  const handleSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    
    try {
   if (editingUser) {
  console.log('✏️ Editando usuario:', editingUser.email);
  
  // --- MODO EDICIÓN ---
  
  // 1. Actualizar Perfil
  const { error: profileError } = await supabase
    .from('profiles')
    .update({ full_name: formData.full_name })
    .eq('id', editingUser.id);

  if (profileError) {
    console.error('Error actualizando perfil:', profileError);
    throw profileError;
  }

  // 2. 🔐 Cambiar contraseña si se proporcionó
  if (formData.password) {
    // Validar que las contraseñas coincidan
    if (formData.password !== formData.confirmPassword) {
      throw new Error('Las contraseñas no coinciden');
    }
    
    if (formData.password.length < 6) {
      throw new Error('La contraseña debe tener al menos 6 caracteres');
    }
    
    try {
      await resetPassword(editingUser.id, formData.password);
      showSuccess('✓ Contraseña actualizada correctamente');
    } catch (pwdError) {
      console.error('Error cambiando contraseña:', pwdError);
      showError('Error al cambiar contraseña: ' + pwdError.message);
      // No lanzamos error para que continúe con el resto
    }
  }

  // 3. Actualizar/Crear Inversión
  let newInvestmentAmount = Number(formData.inversion_actual);
  
  if (formData.add_investment && Number(formData.add_investment) > 0) {
    newInvestmentAmount += Number(formData.add_investment);
    console.log('💰 Aumentando inversión en:', formData.add_investment);
  }

  if (editingUser.investment) {
    const { error: updateInvError } = await supabase
      .from('investments')
      .update({
        inversion_actual: newInvestmentAmount,
        tasa_mensual: Number(formData.tasa_mensual),
        updated_at: new Date().toISOString()
      })
      .eq('id', editingUser.investment.id);

    if (updateInvError) throw updateInvError;
    console.log('✅ Inversión actualizada');
  } else {
    const { error: createInvError } = await supabase
      .from('investments')
      .insert({
        user_id: editingUser.id,
        inversion_actual: newInvestmentAmount,
        tasa_mensual: Number(formData.tasa_mensual)
      });

    if (createInvError) throw createInvError;
    console.log('✅ Inversión creada');
  }

  showSuccess('Usuario actualizado exitosamente');
} else {
        console.log('➕ Creando nuevo usuario');
        
        // --- MODO CREACIÓN ---
        
        if (!formData.password || formData.password.length < 6) {
          throw new Error("La contraseña debe tener al menos 6 caracteres");
        }

        if (!formData.inversion_actual || Number(formData.inversion_actual) <= 0) {
          throw new Error("Debes ingresar un monto de inversión inicial");
        }

        if (!formData.tasa_mensual || Number(formData.tasa_mensual) <= 0) {
          throw new Error("Debes ingresar una tasa mensual");
        }

        // 1. Crear usuario en Auth
        const tempClient = createSecondaryClient();
        console.log('🔐 Creando usuario en Auth...');
        
        const { data: authData, error: authError } = await tempClient.auth.signUp({
          email: formData.email,
          password: formData.password,
          options: {
            data: {
              full_name: formData.full_name
            },
            emailRedirectTo: undefined // Desactivar email de confirmación
          }
        });

        if (authError) {
          console.error('Error en Auth:', authError);
          throw authError;
        }
        
        if (!authData.user) {
          throw new Error("No se pudo crear el usuario");
        }

        const newUserId = authData.user.id;
        console.log('✅ Usuario creado en Auth:', newUserId);

        // 2. Esperar y actualizar perfil
        await new Promise(r => setTimeout(r, 1500));

        const { error: updateProfileError } = await supabase
          .from('profiles')
          .update({ 
            full_name: formData.full_name,
            role: 'cliente' 
          })
          .eq('id', newUserId);

        if (updateProfileError) {
          console.warn('Profile update warning:', updateProfileError);
          // Intentar insert como fallback
          await supabase.from('profiles').upsert({
            id: newUserId,
            email: formData.email,
            full_name: formData.full_name,
            role: 'cliente'
          });
        }

        console.log('✅ Perfil actualizado');

        // 3. ✅ CREAR INVERSIÓN INICIAL CON DATOS
        const { error: invError } = await supabase
          .from('investments')
          .insert({
            user_id: newUserId,
            inversion_actual: Number(formData.inversion_actual),
            tasa_mensual: Number(formData.tasa_mensual),
            ganancia_acumulada: 0,
            created_at: new Date().toISOString()
          });

        if (invError) {
          console.error('Error creando inversión:', invError);
          throw invError;
        }

        console.log('✅ Inversión inicial creada:', {
          inversion: formData.inversion_actual,
          tasa: formData.tasa_mensual
        });

    showSuccess(`Usuario creado: ${formData.email}`);
      }

      setIsModalOpen(false);
      loadUsers(); // Recargar lista
    } catch (error) {
      console.error('❌ Error:', error);
      showError(error.message || "Error al guardar");
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-primary-dark">Gestión de Usuarios</h2>
        <Button onClick={() => handleOpenModal()}>
          <Plus size={18} /> Nuevo Cliente
        </Button>
      </div>

      {loading ? (
        <div className="flex justify-center p-10">
          <Loader2 className="animate-spin text-primary" size={40} />
        </div>
      ) : users.length === 0 ? (
        <Card className="text-center py-10">
          <p className="text-neutral-gray">No hay clientes registrados aún</p>
          <Button onClick={() => handleOpenModal()} className="mt-4">
            <Plus size={18} /> Crear primer cliente
          </Button>
        </Card>
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
                  <Badge variant="primary">
                    Inv: ${user.investment?.inversion_actual?.toLocaleString() || 0}
                  </Badge>
                  <Badge variant="success">
                    Tasa: {user.investment?.tasa_mensual || 0}% mensual
                  </Badge>
                </div>
                
                <div className="flex items-center gap-2 text-status-success font-medium bg-status-success/5 p-2 rounded-lg">
                  <TrendingUp size={16} />
                  <span>Ganancia semanal acumulada: ${calculateGain(user.investment)}</span>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingUser ? "Editar Cliente" : "Nuevo Cliente"}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input 
            label="Nombre Completo"
            value={formData.full_name}
            onChange={e => setFormData({...formData, full_name: e.target.value})}
            required
            placeholder="Juan Pérez"
          />
          
          <Input 
            label="Correo Electrónico"
            type="email"
            value={formData.email}
            onChange={e => setFormData({...formData, email: e.target.value})}
            required
            disabled={!!editingUser}
            placeholder="juan@example.com"
          />

{/* 🔐 NUEVA SECCIÓN DE CONTRASEÑA */}
<div className="space-y-4 border-t pt-4">
  <div className="flex items-center gap-2 text-sm text-neutral-gray">
    <Lock size={16} />
    <span className="font-medium">
      {editingUser ? 'Cambiar Contraseña (Opcional)' : 'Contraseña *'}
    </span>
  </div>

  {/* Campo Contraseña */}
  <div>
    <label className="text-sm font-medium text-neutral-gray block mb-2">
      Nueva Contraseña
    </label>
    <div className="relative">
      <input
        type={showPassword ? "text" : "password"}
        value={formData.password}
        onChange={e => setFormData({...formData, password: e.target.value})}
        placeholder={editingUser ? "Dejar vacío para no cambiar" : "Mínimo 6 caracteres"}
        className="w-full px-4 py-2.5 pr-10 rounded-lg border border-neutral-border focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
      />
      <button
        type="button"
        onClick={() => setShowPassword(!showPassword)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-neutral-gray hover:text-primary"
      >
        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
      </button>
    </div>
  </div>

  {/* Campo Confirmar Contraseña - Solo si hay algo en password */}
  {(formData.password || !editingUser) && (
    <div>
      <label className="text-sm font-medium text-neutral-gray block mb-2">
        Confirmar Contraseña {!editingUser && '*'}
      </label>
      <div className="relative">
        <input
          type={showConfirmPassword ? "text" : "password"}
          value={formData.confirmPassword}
          onChange={e => setFormData({...formData, confirmPassword: e.target.value})}
          placeholder="Repetir contraseña"
          className="w-full px-4 py-2.5 pr-10 rounded-lg border border-neutral-border focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
        />
        <button
          type="button"
          onClick={() => setShowConfirmPassword(!showConfirmPassword)}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-neutral-gray hover:text-primary"
        >
          {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
        </button>
      </div>
      {formData.password !== formData.confirmPassword && formData.confirmPassword && (
        <p className="text-xs text-red-500 mt-1">Las contraseñas no coinciden</p>
      )}
    </div>
  )}

  {/* Alerta de seguridad */}
  {editingUser && formData.password && (
    <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
      <AlertCircle className="text-amber-600 flex-shrink-0 mt-0.5" size={18} />
      <p className="text-xs text-amber-800">
        La contraseña se cambiará inmediatamente. El usuario deberá usar la nueva contraseña en su próximo inicio de sesión.
      </p>
    </div>
  )}
</div>
          <div className="grid grid-cols-2 gap-4">
            <Input 
              label="Inversión Inicial ($)"
              type="number"
              step="0.01"
              value={formData.inversion_actual}
              onChange={e => setFormData({...formData, inversion_actual: e.target.value})}
              disabled={!!editingUser}
              required={!editingUser}
              placeholder="1000"
            />
            <Input 
              label="Tasa Mensual (%)"
              type="number"
              step="0.01"
              value={formData.tasa_mensual}
              onChange={e => setFormData({...formData, tasa_mensual: e.target.value})}
              required
              placeholder="5.5"
            />
          </div>

          {editingUser && (
            <div className="bg-primary-light/30 p-4 rounded-lg border border-primary-light">
              <label className="text-sm font-medium text-primary-dark block mb-2">
                💰 Aumentar Inversión
              </label>
              <Input 
                type="number" 
                step="0.01"
                placeholder="Monto a agregar ($)" 
                value={formData.add_investment}
                onChange={e => setFormData({...formData, add_investment: e.target.value})}
              />
              {formData.add_investment && (
                <p className="text-xs text-neutral-gray mt-2">
                  Nueva inversión total: ${(Number(formData.inversion_actual) + Number(formData.add_investment)).toLocaleString()}
                </p>
              )}
            </div>
          )}

          <Button type="submit" className="w-full mt-4" disabled={actionLoading}>
            {actionLoading ? (
              <>
                <Loader2 className="animate-spin" />
                <span>Guardando...</span>
              </>
            ) : (
              editingUser ? 'Guardar Cambios' : 'Crear Cliente'
            )}
          </Button>
        </form>
      </Modal>
    </div>
  );
}