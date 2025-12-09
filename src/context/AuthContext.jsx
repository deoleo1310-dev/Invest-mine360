// ✅ REEMPLAZAR src/context/AuthContext.jsx

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const clearSession = useCallback(() => {
    try {
      supabase.auth.signOut().catch(() => {});
      setUser(null);
    } catch (error) {
      console.error('Error clearing session:', error);
      setUser(null);
    }
  }, []);

  // ✅ INICIALIZACIÓN OPTIMIZADA CON TIMEOUT REDUCIDO
  useEffect(() => {
    let mounted = true;
    let sessionTimeout = null;

    const initSession = async () => {
      try {
        // ✅ TIMEOUT DE 3 SEGUNDOS (suficiente para Vercel + Supabase)
        sessionTimeout = setTimeout(() => {
          if (mounted) {
            console.warn('⏱️ Timeout de sesión. Continuando como invitado.');
            setLoading(false);
          }
        }, 3000);

        // ✅ USAR getSession() en lugar de getUser() (más rápido)
        const { data: { session }, error } = await supabase.auth.getSession();

        clearTimeout(sessionTimeout);

        if (error || !session?.user) {
          if (mounted) {
            setUser(null);
            setLoading(false);
          }
          return;
        }

        // ✅ CARGAR PERFIL CON ABORT SIGNAL
        try {
          const controller = new AbortController();
          const profileTimeout = setTimeout(() => controller.abort(), 2000);

          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, role')
            .eq('id', session.user.id)
            .abortSignal(controller.signal)
            .maybeSingle();

          clearTimeout(profileTimeout);

          if (mounted) {
            setUser(profile || {
              ...session.user,
              role: 'cliente',
              full_name: session.user.email.split('@')[0]
            });
          }
        } catch (profileError) {
          console.warn('Error cargando perfil:', profileError);
          if (mounted) {
            setUser({
              ...session.user,
              role: 'cliente',
              full_name: session.user.email.split('@')[0]
            });
          }
        }
      } catch (error) {
        console.error('Error de autenticación:', error);
        if (mounted) setUser(null);
      } finally {
        if (mounted) {
          clearTimeout(sessionTimeout);
          setLoading(false);
        }
      }
    };

    initSession();

    // ✅ LISTENER PARA CAMBIOS DE AUTH
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === 'SIGNED_OUT') {
          setUser(null);
        } else if (event === 'SIGNED_IN' && session?.user) {
          try {
            const { data: profile } = await supabase
              .from('profiles')
              .select('id, email, full_name, role')
              .eq('id', session.user.id)
              .maybeSingle();

            setUser(profile || {
              ...session.user,
              role: 'cliente',
              full_name: session.user.email.split('@')[0]
            });
          } catch {
            setUser({
              ...session.user,
              role: 'cliente',
              full_name: session.user.email.split('@')[0]
            });
          }
        }
      }
    );

    return () => {
      mounted = false;
      if (sessionTimeout) clearTimeout(sessionTimeout);
      subscription?.unsubscribe();
    };
  }, []);

  // ✅ LOGIN OPTIMIZADO
  const login = async (email, password) => {
    setLoading(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password 
      });
      
      if (error) throw error;
      
      if (data.session?.user) {
        try {
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, role')
            .eq('id', data.session.user.id)
            .maybeSingle();

          setUser(profile || {
            ...data.session.user,
            role: 'cliente',
            full_name: data.session.user.email.split('@')[0]
          });
        } catch {
          setUser({
            ...data.session.user,
            role: 'cliente',
            full_name: data.session.user.email.split('@')[0]
          });
        }
      }
      
      return data;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    clearSession();
  };

  return (
    <AuthContext.Provider value={{ 
      user, 
      login, 
      logout, 
      loading, 
      isAdmin: user?.role === 'admin' 
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);