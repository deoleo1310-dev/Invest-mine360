import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const isFetching = useRef(false); // Prevenir llamadas duplicadas

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
      console.log('🔔 Auth State Change:', event, session?.user?.email);
      
      // Ignorar TOKEN_REFRESHED para evitar llamadas duplicadas
      if (event === 'TOKEN_REFRESHED') {
        console.log('⏭️ Ignorando TOKEN_REFRESHED');
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

  const fetchProfile = async (authUser) => {
    // Prevenir llamadas simultáneas
    if (isFetching.current) {
      console.log('⏸️ Ya hay una consulta en progreso, saltando...');
      return;
    }

    isFetching.current = true;
    
    try {
      console.log('👤 Buscando perfil para:', authUser.email);
      
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      if (error) {
        console.error('❌ Error al obtener perfil:', error.message, error.code);
        
        // Si el perfil no existe, crearlo
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

          if (createError) {
            console.error('❌ Error creando perfil:', createError.message);
            // Usar datos básicos si falla
            setUser({ 
              ...authUser, 
              role: 'cliente',
              full_name: authUser.email.split('@')[0]
            });
          } else {
            console.log('✅ Perfil creado exitosamente:', newProfile.role);
            setUser({ ...authUser, ...newProfile });
          }
        } else {
          // Otro tipo de error, usar datos básicos
          console.error('⚠️ Error desconocido, usando datos básicos');
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
      // Fallback: establecer usuario con datos básicos
      setUser({ 
        ...authUser, 
        role: 'cliente',
        full_name: authUser.email.split('@')[0]
      });
    } finally {
      setLoading(false);
      isFetching.current = false;
    }
  };

  const login = async (email, password) => {
    try {
      console.log('🔐 Intentando login con:', email);
      setLoading(true); // Activar loading
      
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
      // El loading se desactiva en fetchProfile
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

  useEffect(() => {
    if (user) {
      console.log('👤 Usuario actualizado:', {
        email: user.email,
        role: user.role,
        name: user.full_name
      });
    }
  }, [user]);

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