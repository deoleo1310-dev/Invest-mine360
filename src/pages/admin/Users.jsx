import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import { createSecondaryClient } from '../../lib/adminAuthClient';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { Plus, Pencil, TrendingUp, Loader2, Eye, EyeOff, Lock, AlertCircle, Trash2, Zap } from 'lucide-react';
import { useToast } from '../../context/ToastContext';

export default function AdminUsers() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [deletingUserId, setDeletingUserId] = useState(null);
  const [generatingEarnings, setGeneratingEarnings] = useState(false);
  const { showSuccess, showError, showInfo } = useToast();
  
  const [formData, setFormData] = useState({
    full_name: '',
    email: '',
    password: '',
    confirmPassword: '', 
    inversion_actual: '',
    tasa_diaria: '',
    pendiente: '',
    add_investment: ''
  });

  const loadUsers = async () => {
    try {
      setLoading(true);
      
      const { data, error } = await supabase
        .rpc('get_all_clients_with_investments');

      if (error) throw error;
      
      const usersWithEarnings = data.map(user => ({
        ...user,
        id: user.user_id,
        investment: user.investment_amount > 0 ? {
          inversion_actual: user.investment_amount,
          tasa_diaria: user.daily_rate,
          pendiente: user.pendiente || 0
        } : null,
        totalEarnings: user.total_earnings,
        daysCount: user.days_count,
        dailyRate: user.daily_rate,
        pendiente: user.pendiente || 0
      }));
      
      setUsers(usersWithEarnings);
    } catch (error) {
      showError("Error al cargar usuarios: " + error.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  // ✅ NUEVA FUNCIÓN: Generar Ganancias Diarias
  const handleGenerateEarnings = async () => {
    if (!confirm('¿Generar las ganancias del día para TODOS los usuarios?\n\nEsta acción solo puede hacerse UNA VEZ por día.')) {
      return;
    }

    setGeneratingEarnings(true);

    try {
      const { data, error } = await supabase
        .rpc('generate_daily_earnings_manual');

      if (error) throw error;

      const result = data;

      if (!result.success) {
        showError(result.message);
        return;
      }

      showSuccess(
        `✅ ${result.message}\n\n` +
        `📅 Fecha: ${new Date(result.date).toLocaleDateString('es-DO')}\n` +
        `👥 Usuarios afectados: ${result.users_affected}\n` +
        `💰 Total generado: $${Number(result.total_generated).toLocaleString('es-DO', {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        })}`
      );

      // Recargar usuarios para ver los cambios
      loadUsers();

    } catch (error) {
      console.error('Error generando ganancias:', error);
      showError('Error al generar ganancias: ' + error.message);
    } finally {
      setGeneratingEarnings(false);
    }
  };

  const handleOpenModal = (user = null) => {
    setEditingUser(user);
    if (user) {
      setFormData({
        full_name: user.full_name,
        email: user.email,
        password: '',
        confirmPassword: '',
        inversion_actual: user.investment?.inversion_actual || 0,
        tasa_diaria: user.investment?.tasa_diaria || 0,
        pendiente: user.investment?.pendiente || 0,
        add_investment: ''
      });
    } else {
      setFormData({
        full_name: '',
        email: '',
        password: '',
        confirmPassword: '',
        inversion_actual: '',
        tasa_diaria: '',
        pendiente: '',
        add_investment: ''
      });
    }
    setIsModalOpen(true);
  };

  const handleDeleteUser = async (userId, userName) => {
    if (!confirm(`¿Estás seguro de eliminar a ${userName}?\n\nEsta acción NO se puede deshacer y eliminará:\n- Su perfil\n- Su inversión\n- Todos sus retiros\n\n¿Continuar?`)) {
      return;
    }

    setDeletingUserId(userId);

    try {
      await supabase.from('withdrawals').delete().eq('user_id', userId);

      const { data: inv } = await supabase
        .from('investments')
        .select('id')
        .eq('user_id', userId)
        .single();

      if (inv) {
        await supabase.from('investment_history').delete().eq('investment_id', inv.id);
      }

      await supabase.from('investments').delete().eq('user_id', userId);

      const { error: profileError } = await supabase
        .from('profiles')
        .delete()
        .eq('id', userId);

      if (profileError) throw profileError;

      showSuccess(`Usuario ${userName} eliminado exitosamente`);
      loadUsers();
    } catch (error) {
      showError('Error al eliminar: ' + error.message);
    } finally {
      setDeletingUserId(null);
    }
  };

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
      throw error;
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    
    try {
      if (editingUser) {
        const { error: profileError } = await supabase
          .from('profiles')
          .update({ full_name: formData.full_name })
          .eq('id', editingUser.id);

        if (profileError) throw profileError;

        if (formData.password) {
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
            showError('Error al cambiar contraseña: ' + pwdError.message);
          }
        }

        let newInvestmentAmount = Number(formData.inversion_actual);
        
        if (formData.add_investment && Number(formData.add_investment) > 0) {
          newInvestmentAmount += Number(formData.add_investment);
        }

        if (editingUser.investment) {
          const { data: inv } = await supabase
            .from('investments')
            .select('id')
            .eq('user_id', editingUser.id)
            .single();

          if (inv) {
            const { error: updateInvError } = await supabase
              .from('investments')
              .update({
                inversion_actual: newInvestmentAmount,
                tasa_diaria: Number(formData.tasa_diaria),
                pendiente: Number(formData.pendiente || 0),
                updated_at: new Date().toISOString()
              })
              .eq('id', inv.id);

            if (updateInvError) throw updateInvError;
          }
        } else {
          const { error: createInvError } = await supabase
            .from('investments')
            .insert({
              user_id: editingUser.id,
              inversion_actual: newInvestmentAmount,
              tasa_diaria: Number(formData.tasa_diaria),
              pendiente: Number(formData.pendiente || 0)
            });

          if (createInvError) throw createInvError;
        }

        showSuccess('Usuario actualizado exitosamente');
      } else {
        if (!formData.password || formData.password.length < 6) {
          throw new Error("La contraseña debe tener al menos 6 caracteres");
        }

        if (!formData.inversion_actual || Number(formData.inversion_actual) <= 0) {
          throw new Error("Debes ingresar un monto de inversión inicial");
        }

        if (!formData.tasa_diaria || Number(formData.tasa_diaria) <= 0) {
          throw new Error("Debes ingresar una tasa diaria");
        }

        const tempClient = createSecondaryClient();
        
        const { data: authData, error: authError } = await tempClient.auth.signUp({
          email: formData.email,
          password: formData.password,
          options: {
            data: {
              full_name: formData.full_name
            },
            emailRedirectTo: undefined
          }
        });

        if (authError) throw authError;
        if (!authData.user) throw new Error("No se pudo crear el usuario");

        const newUserId = authData.user.id;
        
        await new Promise(r => setTimeout(r, 1500));

        const { error: updateProfileError } = await supabase
          .from('profiles')
          .update({ 
            full_name: formData.full_name,
            role: 'cliente' 
          })
          .eq('id', newUserId);

        if (updateProfileError) {
          await supabase.from('profiles').upsert({
            id: newUserId,
            email: formData.email,
            full_name: formData.full_name,
            role: 'cliente'
          });
        }

        const { error: invError } = await supabase
          .from('investments')
          .insert({
            user_id: newUserId,
            inversion_actual: Number(formData.inversion_actual),
            tasa_diaria: Number(formData.tasa_diaria),
            pendiente: Number(formData.pendiente || 0),
            ganancia_acumulada: 0,
            created_at: new Date().toISOString()
          });

        if (invError) throw invError;

        showSuccess(`Usuario creado: ${formData.email}`);
      }

      setIsModalOpen(false);
      loadUsers();
    } catch (error) {
      showError(error.message || "Error al guardar");
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h2 className="text-2xl font-bold text-primary-dark">Gestión de Usuarios</h2>
        
        <div className="flex gap-2">
          {/* ✅ BOTÓN GENERAR GANANCIAS */}
          <Button 
            onClick={handleGenerateEarnings}
            disabled={generatingEarnings}
            className="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700"
          >
            {generatingEarnings ? (
              <>
                <Loader2 className="animate-spin" size={18} />
                <span>Generando...</span>
              </>
            ) : (
              <>
                <Zap size={18} />
                <span>Generar Ganancias</span>
              </>
            )}
          </Button>

          <Button onClick={() => handleOpenModal()}>
            <Plus size={18} /> Nuevo Cliente
          </Button>
        </div>
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
                onClick={() => handleDeleteUser(user.id, user.full_name)}
                disabled={deletingUserId === user.id}
                className="absolute top-4 right-14 text-red-500 hover:text-red-700 p-2 hover:bg-red-50 rounded-full transition-colors disabled:opacity-50"
                title="Eliminar usuario"
              >
                {deletingUserId === user.id ? (
                  <Loader2 className="animate-spin" size={18} />
                ) : (
                  <Trash2 size={18} />
                )}
              </button>

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
                    Inv: ${user.investment_amount?.toLocaleString() || 0}
                  </Badge>
                  <Badge variant="success">
                    Tasa: {user.daily_rate || 0}% diaria
                  </Badge>
                  {/* ✅ BADGE FALTANTE */}
                  {user.pendiente > 0 && (
                    <Badge variant="warning">
                      Faltante: ${Number(user.pendiente).toLocaleString()}
                    </Badge>
                  )}
                </div>
                
                <div className="flex items-center gap-2 text-status-success font-medium bg-status-success/5 p-2 rounded-lg">
                  <TrendingUp size={16} />
                  <span>
                    Ganancia acumulada: ${Number(user.totalEarnings || 0).toLocaleString('es-DO', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })}
                  </span>
                  {user.daysCount > 0 && (
                    <span className="text-xs text-neutral-gray ml-2">
                      ({user.daysCount} días × {user.dailyRate}%)
                    </span>
                  )}
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
        <div className="space-y-4">
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

          <div className="space-y-4 border-t pt-4">
            <div className="flex items-center gap-2 text-sm text-neutral-gray">
              <Lock size={16} />
              <span className="font-medium">
                {editingUser ? 'Cambiar Contraseña (Opcional)' : 'Contraseña *'}
              </span>
            </div>

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

            {editingUser && formData.password && (
              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
                <AlertCircle className="text-amber-600 flex-shrink-0 mt-0.5" size={18} />
                <p className="text-xs text-amber-800">
                  La contraseña se cambiará inmediatamente.
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
              label="Tasa Diaria (%)"
              type="number"
              step="0.0001"
              value={formData.tasa_diaria}
              onChange={e => setFormData({...formData, tasa_diaria: e.target.value})}
              required
              placeholder="0.1833"
            />
          </div>

          {/* ✅ CAMPO FALTANTE */}
          <Input 
            label="💳 Faltante ($)"
            type="number"
            step="0.01"
            value={formData.pendiente}
            onChange={e => setFormData({...formData, pendiente: e.target.value})}
            placeholder="0"
          />

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

          <Button 
            onClick={handleSubmit} 
            className="w-full mt-4" 
            disabled={actionLoading}
          >
            {actionLoading ? (
              <>
                <Loader2 className="animate-spin" />
                <span>Guardando...</span>
              </>
            ) : (
              editingUser ? 'Guardar Cambios' : 'Crear Cliente'
            )}
          </Button>
        </div>
      </Modal>
    </div>
  );
}