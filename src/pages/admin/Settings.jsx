import React, { useState, useEffect } from 'react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { useSettingsStore } from '../../store/settingsStore';
import { useToast } from '../../context/ToastContext';
import { Save, Loader2, Link as LinkIcon, Palette, Percent } from 'lucide-react';

export default function AdminSettings() {
  const { settings, updateSettings, loading } = useSettingsStore();
  const { showSuccess, showError } = useToast();
  const [saving, setSaving] = useState(false);
  
  const [formData, setFormData] = useState({
    app_name: '',
    paypal_link: '',
    whatsapp_link: '',
    primary_color: '#3b82f6',
    secondary_color: '#1e40af',
    default_rate_value: 0,
    default_rate_period: 'mensual'
  });

  useEffect(() => {
    if (settings) {
      setFormData({
        app_name: settings.app_name || '',
        paypal_link: settings.paypal_link || '',
        whatsapp_link: settings.whatsapp_link || '',
        primary_color: settings.primary_color || '#3b82f6',
        secondary_color: settings.secondary_color || '#1e40af',
        default_rate_value: settings.default_rate_value || 0,
        default_rate_period: settings.default_rate_period || 'mensual'
      });
    }
  }, [settings]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    
    // Ensure numbers are numbers
    const payload = {
      ...formData,
      default_rate_value: Number(formData.default_rate_value)
    };

    const result = await updateSettings(payload);
    
    setSaving(false);
    
    if (result.success) {
      showSuccess('Configuración guardada exitosamente.');
    } else {
      showError('Error al guardar: ' + result.error);
    }
  };

  if (loading && !settings) {
    return (
      <div className="flex justify-center p-10">
        <Loader2 className="animate-spin text-primary" size={40} />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-primary-dark">Configuración General</h2>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        
        {/* Branding */}
        <Card>
          <div className="flex items-center gap-2 mb-4 text-primary">
            <Palette size={20} />
            <h3 className="text-lg font-semibold">Branding y Diseño</h3>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input 
              label="Nombre de la Aplicación"
              value={formData.app_name}
              onChange={e => setFormData({...formData, app_name: e.target.value})}
              required
            />
            
            <div className="flex gap-4">
              <div className="flex-1">
                <label className="text-sm font-medium text-neutral-gray block mb-2">
                  Color Primario
                </label>
                <div className="flex items-center gap-3">
                  <input 
                    type="color" 
                    value={formData.primary_color}
                    onChange={e => setFormData({...formData, primary_color: e.target.value})}
                    className="w-10 h-10 rounded cursor-pointer border custom-color-picker"
                  />
                  <span className="text-sm text-neutral-gray">{formData.primary_color}</span>
                </div>
              </div>
              <div className="flex-1">
                <label className="text-sm font-medium text-neutral-gray block mb-2">
                  Color Secundario
                </label>
                <div className="flex items-center gap-3">
                  <input 
                    type="color" 
                    value={formData.secondary_color}
                    onChange={e => setFormData({...formData, secondary_color: e.target.value})}
                    className="w-10 h-10 rounded cursor-pointer border custom-color-picker"
                  />
                  <span className="text-sm text-neutral-gray">{formData.secondary_color}</span>
                </div>
              </div>
            </div>
          </div>
        </Card>

        {/* Links */}
        <Card>
          <div className="flex items-center gap-2 mb-4 text-primary">
            <LinkIcon size={20} />
            <h3 className="text-lg font-semibold">Enlaces Externos</h3>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input 
              label="Enlace de PayPal"
              type="url"
              value={formData.paypal_link}
              onChange={e => setFormData({...formData, paypal_link: e.target.value})}
              required
              placeholder="https://paypal.me/usuario"
            />
            <Input 
              label="Enlace de WhatsApp (Opcional)"
              type="url"
              value={formData.whatsapp_link}
              onChange={e => setFormData({...formData, whatsapp_link: e.target.value})}
              placeholder="https://wa.me/1234567890"
            />
          </div>
        </Card>

        {/* Financial */}
        <Card>
          <div className="flex items-center gap-2 mb-4 text-primary">
            <Percent size={20} />
            <h3 className="text-lg font-semibold">Tasas y Finanzas</h3>
          </div>
          <p className="text-sm text-neutral-gray mb-4">
            Esta es la tasa **por defecto** que se mostrará y utilizará para los clientes nuevos. 
            El servidor automáticamente la convertirá a tasa diaria para los cálculos internos.
          </p>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input 
              label="Porcentaje Base (%)"
              type="number"
              step="0.01"
              value={formData.default_rate_value}
              onChange={e => setFormData({...formData, default_rate_value: e.target.value})}
              required
            />
            
            <div>
              <label className="text-sm font-medium text-neutral-gray block mb-2">
                Período de la Tasa
              </label>
              <select 
                value={formData.default_rate_period}
                onChange={e => setFormData({...formData, default_rate_period: e.target.value})}
                className="w-full px-4 py-2.5 rounded-lg border border-neutral-border focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
              >
                <option value="diaria">Diaria</option>
                <option value="semanal">Semanal</option>
                <option value="mensual">Mensual</option>
              </select>
            </div>
          </div>
        </Card>

        <div className="flex justify-end pb-10">
          <Button 
            type="submit" 
            disabled={saving}
          >
            {saving ? (
              <>
                <Loader2 className="animate-spin mr-2" size={18} />
                Guardando...
              </>
            ) : (
              <>
                <Save className="mr-2" size={18} />
                Guardar Configuración
              </>
            )}
          </Button>
        </div>

      </form>
    </div>
  );
}
