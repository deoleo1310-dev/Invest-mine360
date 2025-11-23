import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes('YOUR_API_KEY')) {
  console.error('ERROR CRÍTICO: Faltan las credenciales de Supabase en el archivo .env');
}

export const supabase = createClient(
  supabaseUrl, 
  supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    }
  }
);
/*
 import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// 🔍 TEST RÁPIDO
(async () => {
  const { data, error } = await supabase.from("profiles").select("*").limit(1);

  if (error) {
    console.error("❌ Error conectando a Supabase:", error);
  } else {
    console.log("✅ Conectado a Supabase:", data);
  }
})();
  */