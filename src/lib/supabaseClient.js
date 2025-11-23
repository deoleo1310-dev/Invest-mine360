import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// ✅ Verificación mejorada
if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ ERROR CRÍTICO: Faltan las credenciales de Supabase');
  console.error('URL:', supabaseUrl ? '✓' : '✗');
  console.error('ANON_KEY:', supabaseAnonKey ? '✓' : '✗');
}

console.log('🔗 Conectando a Supabase:', supabaseUrl);

export const supabase = createClient(
  supabaseUrl, 
  supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storage: window.localStorage,
    }
  }
);

// ✅ Test de conexión automático (solo en desarrollo)
if (import.meta.env.DEV) {
  (async () => {
    try {
      const { data, error } = await supabase.from("profiles").select("count").limit(1);
      
      if (error) {
        console.error("❌ Error conectando a Supabase:", error.message);
      } else {
        console.log("✅ Conexión exitosa a Supabase");
      }
    } catch (err) {
      console.error("❌ Error de red con Supabase:", err);
    }
  })();
}