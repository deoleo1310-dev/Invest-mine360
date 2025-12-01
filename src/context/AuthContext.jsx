import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabaseClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // ✅ OPTIMIZACIÓN: Fetch más rápido con abort controller
  const fetchProfile = useCallback(async (authUser, signal) => {
    try {
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('id, email, full_name, role')
        .eq('id', authUser.id)
        .abortSignal(signal)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.warn('Profile fetch error:', error.message);
        return { 
          ...authUser, 
          role: 'cliente',
          full_name: authUser.email.split('@')[0]
        };
      }

      return profile ? { ...authUser, ...profile } : {
        ...authUser,
        role: 'cliente',
        full_name: authUser.user_metadata?.full_name || authUser.email.split('@')[0]
      };
    } catch (error) {
      if (error.name === 'AbortError') throw error;
      return { 
        ...authUser, 
        role: 'cliente',
        full_name: authUser.email.split('@')[0]
      };
    }
  }, []);

  useEffect(() => {
    const abortController = new AbortController();
    let mounted = true;
    
    const initSession = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        
        if (session?.user && mounted) {
          const userData = await fetchProfile(session.user, abortController.signal);
          if (mounted) setUser(userData);
        }
      } catch (error) {
        if (error.name !== 'AbortError') {
          console.error('Session init error:', error);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    };

    initSession();

    // ✅ OPTIMIZACIÓN: Solo escuchar cambios importantes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (!mounted) return;
        
        // Ignorar eventos que no cambian el estado
        if (event === 'TOKEN_REFRESHED') return;
        
        if (event === 'SIGNED_IN' && session?.user) {
          const userData = await fetchProfile(session.user, abortController.signal);
          if (mounted) setUser(userData);
        } else if (event === 'SIGNED_OUT') {
          setUser(null);
        }
      }
    );

    return () => {
      mounted = false;
      abortController.abort();
      subscription.unsubscribe();
    };
  }, [fetchProfile]);

  const login = async (email, password) => {
    setLoading(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ 
        email, 
        password 
      });
      
      if (error) throw error;
      return data;
    } finally {
      setLoading(false);
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