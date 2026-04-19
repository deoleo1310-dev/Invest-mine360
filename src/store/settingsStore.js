import { create } from 'zustand';
import { supabase } from '../lib/supabaseClient';

export const useSettingsStore = create((set, get) => ({
  settings: {
    app_name: 'Mine360pr',
    paypal_link: '',
    whatsapp_link: '',
    primary_color: '#1464F4',
    secondary_color: '#0A2A6E',
    default_rate_value: 15,
    default_rate_period: 'mensual'
  },
  loading: false,
  error: null,
  
  fetchSettings: async () => {
    set({ loading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('app_settings')
        .select('*')
        .single();
        
      if (error) {
         if (error.code === 'PGRST116') {
             // Si no hay fila, usamos los defaults
             set({ loading: false });
             return;
         }
         throw error;
      }
      
      // Actualizar variables de entorno CSS
      if (data.primary_color) {
        // Asume variables de config de Tailwind o globals.css
        document.documentElement.style.setProperty('--primary-color', data.primary_color);
      }
      if (data.secondary_color) {
        document.documentElement.style.setProperty('--secondary-color', data.secondary_color);
      }
      
      set({ settings: data, loading: false });
    } catch (err) {
      console.error("Error cargando configuración:", err.message);
      set({ error: err.message, loading: false });
    }
  },
  
  updateSettings: async (newSettings) => {
    try {
      const { data, error } = await supabase
        .from('app_settings')
        .update(newSettings)
        .eq('id', true)
        .select()
        .single();
        
      if (error) throw error;
      
      if (data.primary_color) {
        document.documentElement.style.setProperty('--primary-color', data.primary_color);
      }
      
      if (data.secondary_color) {
        document.documentElement.style.setProperty('--secondary-color', data.secondary_color);
      }
      
      set({ settings: data });
      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
}));
