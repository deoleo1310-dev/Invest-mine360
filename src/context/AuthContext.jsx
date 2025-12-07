import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // ✅ Limpiar sesión sin ser agresivo
  const clearSession = useCallback(() => {
    try {
      supabase.auth.signOut().catch(() => {});
      setUser(null);
    } catch (error) {
      console.error('Error clearing session:', error);
      setUser(null);
    }
  }, []);

  // ✅ INICIALIZACIÓN CON TIMEOUT RAZONABLE
  useEffect(() => {
    let mounted = true;
    let sessionTimeout = null;

    const initSession = async () => {
      try {
        // ✅ Timeout de 10 segundos (razonable para cold starts)
        sessionTimeout = setTimeout(() => {
          if (mounted) {
            console.warn('⏱️ Timeout verificando sesión. Continuando sin autenticación.');
            setLoading(false);
          }
        }, 10000);

        const { data: { session }, error } = await supabase.auth.getSession();

        clearTimeout(sessionTimeout);

        if (error) {
          console.error('Error de sesión:', error);
          if (mounted) {
            setUser(null);
            setLoading(false);
          }
          return;
        }

        if (!session?.user) {
          if (mounted) {
            setUser(null);
            setLoading(false);
          }
          return;
        }

        // ✅ Cargar perfil con timeout separado
        try {
          const profileController = new AbortController();
          const profileTimeout = setTimeout(() => profileController.abort(), 5000);

          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, role')
            .eq('id', session.user.id)
            .abortSignal(profileController.signal)
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
        if (mounted) {
          setUser(null);
        }
      } finally {
        if (mounted) {
          clearTimeout(sessionTimeout);
          setLoading(false);
        }
      }
    };

    initSession();

    return () => {
      mounted = false;
      if (sessionTimeout) clearTimeout(sessionTimeout);
    };
  }, []);

  // ✅ LOGIN con actualización inmediata
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
        } catch (profileError) {
          console.warn('Error cargando perfil:', profileError);
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

  // ✅ LOGOUT simple
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