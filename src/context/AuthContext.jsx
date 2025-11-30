import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const isFetching = useRef(false); // Prevenir llamadas duplicadas

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
      
      
      // Ignorar TOKEN_REFRESHED para evitar llamadas duplicadas
      if (event === 'TOKEN_REFRESHED') {
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

  const fetchProfile = async (authUser) => {
    // Prevenir llamadas simultáneas
    if (isFetching.current) {
      
      return;
    }

    isFetching.current = true;
    
    try {
     
      
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      if (error) {
    
        
        // Si el perfil no existe, crearlo
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

          if (createError) {
           
            // Usar datos básicos si falla
            setUser({ 
              ...authUser, 
              role: 'cliente',
              full_name: authUser.email.split('@')[0]
            });
          } else {
            
            setUser({ ...authUser, ...newProfile });
          }
        } else {
          // Otro tipo de error, usar datos básicos
          
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
     
      setLoading(true); // Activar loading
      
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password 
      });
      
      if (error) {
       
        setLoading(false);
        throw error;
      }
      
     
      // El loading se desactiva en fetchProfile
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

  useEffect(() => {
    if (user) {
      
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