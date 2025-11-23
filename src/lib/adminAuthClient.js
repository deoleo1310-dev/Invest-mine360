import { createClient } from '@supabase/supabase-js';

// Helper para almacenamiento en memoria (evita conflictos con localStorage del Admin)
class InMemoryStorage {
  constructor() { this.storage = new Map(); }
  getItem(key) { return this.storage.get(key); }
  setItem(key, value) { this.storage.set(key, value); }
  removeItem(key) { this.storage.delete(key); }
}

// Cliente secundario aislado para crear usuarios sin cerrar la sesión del Admin
export const createSecondaryClient = () => {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

  return createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      storage: new InMemoryStorage(),
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false
    }
  });
};
