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
   
    
    const getSession = async () => {
      try {
        
        const { data: { session }, error } = await supabase.auth.getSession();
        
        if (error) {
         
          setLoading(false);
          return;
        }

        if (session?.user) {
         
          await fetchProfile(session.user);
        } else {
          
          setLoading(false);
        }
      } catch (error) {
       
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
      
      return;
    }

    isFetching.current = true;
    lastFetchTime.current = now;
    
    try {
     
      
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      if (error) {
        console.error('❌ Error al obtener perfil:', error.message);
        
        // ✅ FALLBACK: Crear perfil si no existe
        if (error.code === 'PGRST116') {
          
          
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
       
        setLoading(false);
        throw error;
      }
      
      console.log('✅ Login exitoso');
      return data;
    } catch (error) {
      
      setLoading(false);
      throw error;
    }
  };

  const logout = async () => {
    
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