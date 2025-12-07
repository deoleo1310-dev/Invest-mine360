import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // ✅ FUNCIÓN: Limpiar sesión FORZADA
  const clearSession = useCallback(() => {
    try {
      // NO AWAIT - Limpieza inmediata sin esperar a Supabase
      supabase.auth.signOut().catch(() => {}); // Fire and forget
      localStorage.clear();
      sessionStorage.clear();
      setUser(null);
    } catch (error) {
      console.error('Error clearing session:', error);
      localStorage.clear();
      sessionStorage.clear();
      setUser(null);
    }
  }, []);

  // ✅ EFECTO: Inicialización AGRESIVA con timeout instantáneo
  useEffect(() => {
    let mounted = true;
    let timeoutId = null;
    let forceStopTimeout = null;

    const initSession = async () => {
      try {
        // 🔥 TIMEOUT AGRESIVO: 3 segundos máximo
        forceStopTimeout = setTimeout(() => {
          if (mounted) {
            console.warn('⚠️ Supabase no responde. Forzando logout...');
            localStorage.clear();
            sessionStorage.clear();
            setUser(null);
            setLoading(false);
          }
        }, 3000);

        // Intentar obtener sesión con timeout
        const controller = new AbortController();
        timeoutId = setTimeout(() => controller.abort(), 2000);

        const { data: { session }, error } = await supabase.auth.getSession();

        clearTimeout(timeoutId);
        clearTimeout(forceStopTimeout);

        // Si hay error o no hay sesión, limpiar TODO
        if (error || !session?.user) {
          if (mounted) {
            console.log('❌ Sin sesión válida, limpiando...');
            localStorage.clear();
            sessionStorage.clear();
            setUser(null);
          }
        } else if (mounted) {
          // Sesión válida, intentar cargar perfil (con timeout también)
          try {
            const profileTimeout = setTimeout(() => {
              throw new Error('Profile timeout');
            }, 2000);

            const { data: profile } = await supabase
              .from('profiles')
              .select('id, email, full_name, role')
              .eq('id', session.user.id)
              .maybeSingle();

            clearTimeout(profileTimeout);

            if (mounted) {
              setUser(profile ? { ...session.user, ...profile } : {
                ...session.user,
                role: 'cliente',
                full_name: session.user.email.split('@')[0]
              });
            }
          } catch (profileError) {
            console.warn('⚠️ Error cargando perfil:', profileError);
            if (mounted) {
              // Si falla el perfil, aún así mostrar sesión básica
              setUser({
                ...session.user,
                role: 'cliente',
                full_name: session.user.email.split('@')[0]
              });
            }
          }
        }
      } catch (error) {
        console.error('❌ Error de sesión:', error);
        if (mounted) {
          localStorage.clear();
          sessionStorage.clear();
          setUser(null);
        }
      } finally {
        if (mounted) {
          clearTimeout(timeoutId);
          clearTimeout(forceStopTimeout);
          setLoading(false);
        }
      }
    };

    initSession();

    return () => {
      mounted = false;
      if (timeoutId) clearTimeout(timeoutId);
      if (forceStopTimeout) clearTimeout(forceStopTimeout);
    };
  }, []);

  // ✅ LOGIN: Con actualización inmediata de estado
  const login = async (email, password) => {
    setLoading(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password 
      });
      
      if (error) throw error;
      
      // ✅ IMPORTANTE: Actualizar el estado inmediatamente después del login
      if (data.session?.user) {
        try {
          // Intentar cargar perfil
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, role')
            .eq('id', data.session.user.id)
            .maybeSingle();

          // Actualizar estado inmediatamente
          setUser(profile ? { ...data.session.user, ...profile } : {
            ...data.session.user,
            role: 'cliente',
            full_name: data.session.user.email.split('@')[0]
          });
        } catch (profileError) {
          console.warn('Error cargando perfil después del login:', profileError);
          // Si falla el perfil, usar datos básicos
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

  // ✅ LOGOUT: Limpieza inmediata sin esperar
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