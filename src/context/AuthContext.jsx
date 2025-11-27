import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const isFetching = useRef(false);
  const lastFetchTime = useRef(0); // ✅ Previene fetches duplicados

  // ✅ DEBOUNCE: Evita llamadas múltiples en <300ms
  const debounce = (fn, delay) => {
    let timeoutId;
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => fn(...args), delay);
    };
  };

  useEffect(() => {
    console.log('🔄 AuthContext: Inicializando...');
    
    const getSession = async () => {
      try {
        console.log('📡 Obteniendo sesión...');
        const { data: { session }, error } = await supabase.auth.getSession();
        
        if (error) {
          console.error('❌ Error obteniendo sesión:', error);
          setLoading(false);
          return;
        }

        if (session?.user) {
          console.log('✅ Sesión encontrada:', session.user.email);
          await fetchProfile(session.user);
        } else {
          console.log('ℹ️ No hay sesión activa');
          setLoading(false);
        }
      } catch (error) {
        console.error('❌ Error en getSession:', error);
        setLoading(false);
      }
    };

    getSession();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('🔔 Auth State Change:', event);
      
      // ✅ IGNORAR eventos que no cambian el estado real
      if (event === 'TOKEN_REFRESHED' || event === 'INITIAL_SESSION') {
        console.log('⏭️ Ignorando', event);
        return;
      }
      
      if (session?.user && event === 'SIGNED_IN') {
        await fetchProfile(session.user);
      } else if (event === 'SIGNED_OUT') {
        setUser(null);
        setLoading(false);
      }
    });

    return () => {
      console.log('🧹 Limpiando suscripción');
      subscription.unsubscribe();
    };
  }, []);

  // ✅ CACHE DE 1 SEGUNDO: Previene fetches duplicados
  const fetchProfile = useCallback(async (authUser) => {
    const now = Date.now();
    
    // Si ya se hizo fetch hace menos de 1 segundo, ignorar
    if (now - lastFetchTime.current < 1000) {
      console.log('⏸️ Fetch muy reciente, ignorando...');
      return;
    }

    if (isFetching.current) {
      console.log('⏸️ Ya hay una consulta en progreso, saltando...');
      return;
    }

    isFetching.current = true;
    lastFetchTime.current = now;
    
    try {
      console.log('👤 Buscando perfil para:', authUser.email);
      
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      if (error) {
        console.error('❌ Error al obtener perfil:', error.message);
        
        // ✅ FALLBACK: Crear perfil si no existe
        if (error.code === 'PGRST116') {
          console.log('⚠️ Perfil no encontrado, creando...');
          
          const { data: newProfile, error: createError } = await supabase
            .from('profiles')
            .insert({
              id: authUser.id,
              email: authUser.email,
              full_name: authUser.user_metadata?.full_name || authUser.email.split('@')[0],
              role: 'cliente'
            })
            .select()
            .single();

          if (!createError && newProfile) {
            console.log('✅ Perfil creado:', newProfile.role);
            setUser({ ...authUser, ...newProfile });
          } else {
            console.error('❌ Error creando perfil:', createError);
            setUser({ 
              ...authUser, 
              role: 'cliente',
              full_name: authUser.email.split('@')[0]
            });
          }
        } else {
          // Otro error, usar datos básicos
          setUser({ 
            ...authUser, 
            role: 'cliente',
            full_name: authUser.email.split('@')[0]
          });
        }
      } else {
        console.log('✅ Perfil encontrado:', profile.role);
        setUser({ ...authUser, ...profile });
      }
    } catch (error) {
      console.error('❌ Excepción en fetchProfile:', error);
      setUser({ 
        ...authUser, 
        role: 'cliente',
        full_name: authUser.email.split('@')[0]
      });
    } finally {
      setLoading(false);
      isFetching.current = false;
    }
  }, []);

  const login = async (email, password) => {
    try {
      console.log('🔐 Intentando login con:', email);
      setLoading(true);
      
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password 
      });
      
      if (error) {
        console.error('❌ Error en login:', error.message);
        setLoading(false);
        throw error;
      }
      
      console.log('✅ Login exitoso');
      return data;
    } catch (error) {
      console.error('❌ Excepción en login:', error);
      setLoading(false);
      throw error;
    }
  };

  const logout = async () => {
    console.log('👋 Cerrando sesión...');
    await supabase.auth.signOut();
    setUser(null);
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