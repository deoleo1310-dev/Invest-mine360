/**
 * FAKE SUPABASE IMPLEMENTATION
 * 
 * Este archivo simula una base de datos y cliente de Supabase.
 * Utiliza localStorage para persistir los datos entre recargas.
 */

// Se ha eliminado la importación de 'uuid' para evitar errores de dependencia, 
// ya que usamos generateId() nativo abajo.

const generateId = () => Math.random().toString(36).substr(2, 9);

// Datos iniciales para poblar la "BD" si está vacía
const INITIAL_DATA = {
  profiles: [
    {
      id: 'admin-123',
      email: 'admin@investpro.com',
      password: 'admin', // En prod real esto nunca se guarda en texto plano
      full_name: 'Administrador Principal',
      role: 'admin',
      created_at: new Date().toISOString()
    },
    {
      id: 'user-1',
      email: 'cliente@test.com',
      password: '123',
      full_name: 'Juan Pérez',
      role: 'cliente',
      created_at: new Date('2024-01-15').toISOString()
    }
  ],
  investments: [
    {
      id: 'inv-1',
      user_id: 'user-1',
      inversion_actual: 10000,
      tasa_mensual: 1.25,
      ganancia_acumulada: 1500,
      created_at: new Date('2024-01-15').toISOString()
    }
  ],
  withdrawals: [
    {
      id: 'wd-1',
      user_id: 'user-1',
      monto: 500,
      estado: 'pendiente', // pendiente, pagado, rechazado
      fecha_solicitud: new Date().toISOString(),
      fecha_procesado: null
    }
  ]
};

// Helper para cargar/guardar en localStorage
const loadDB = () => {
  const db = localStorage.getItem('investpro_db');
  return db ? JSON.parse(db) : INITIAL_DATA;
};

const saveDB = (data) => {
  localStorage.setItem('investpro_db', JSON.stringify(data));
};

// Inicializar DB
if (!localStorage.getItem('investpro_db')) {
  saveDB(INITIAL_DATA);
}

export const fakeSupabase = {
  auth: {
    signInWithPassword: async ({ email, password }) => {
      const db = loadDB();
      const user = db.profiles.find(u => u.email === email && u.password === password);
      
      if (user) {
        // Simular sesión
        const session = { user, access_token: 'fake-jwt-token' };
        localStorage.setItem('investpro_session', JSON.stringify(session));
        return { data: { session, user }, error: null };
      }
      return { data: null, error: { message: 'Credenciales inválidas' } };
    },
    signOut: async () => {
      localStorage.removeItem('investpro_session');
      return { error: null };
    },
    getSession: async () => {
      const session = JSON.parse(localStorage.getItem('investpro_session'));
      return { data: { session }, error: null };
    },
    getUser: async () => {
        const session = JSON.parse(localStorage.getItem('investpro_session'));
        return { data: { user: session?.user || null }, error: null };
    }
  },
  
  // Simulación de consultas a tablas
  from: (table) => {
    const db = loadDB();
    let data = db[table] || [];
    let error = null;

    return {
      select: (columns = '*') => {
        // En esta simulación simple, siempre devolvemos todo y filtramos después si es necesario
        // Para simular joins (investments de usuarios), lo haremos manualmente en el frontend o aquí
        return {
          eq: (field, value) => {
            const filtered = data.filter(item => item[field] === value);
            return { data: filtered, error };
          },
          order: (field, { ascending = true } = {}) => {
             data.sort((a, b) => {
                if (a[field] < b[field]) return ascending ? -1 : 1;
                if (a[field] > b[field]) return ascending ? 1 : -1;
                return 0;
             });
             return { data, error };
          },
          data,
          error
        };
      },
      insert: (newData) => {
        const item = { id: generateId(), created_at: new Date().toISOString(), ...newData };
        if(Array.isArray(newData)) {
             // Handle array insert if needed
        }
        db[table].push(item);
        saveDB(db);
        return { data: [item], error };
      },
      update: (updates) => {
        return {
          eq: (field, value) => {
            const index = db[table].findIndex(item => item[field] === value);
            if (index !== -1) {
              db[table][index] = { ...db[table][index], ...updates, updated_at: new Date().toISOString() };
              saveDB(db);
              return { data: [db[table][index]], error };
            }
            return { data: null, error: { message: 'Not found' } };
          }
        };
      },
      delete: () => { 
         return {
             eq: (field, value) => {
                 db[table] = db[table].filter(item => item[field] !== value);
                 saveDB(db);
                 return { error: null };
             }
         }
      }
    };
  },

  // Función helper específica para obtener usuarios con sus inversiones (Join simulado)
  getUsersWithInvestments: async () => {
    const db = loadDB();
    const users = db.profiles.filter(u => u.role === 'cliente');
    const investments = db.investments;
    
    return users.map(user => {
      const inv = investments.find(i => i.user_id === user.id);
      return {
        ...user,
        investment: inv || null
      };
    });
  },

  // Función para crear usuario completo (perfil + inversión)
  createClientWithInvestment: async ({ email, password, full_name, inversion_actual, tasa_mensual }) => {
    const db = loadDB();
    
    // Check if email exists
    if (db.profiles.some(u => u.email === email)) {
      return { error: { message: 'El email ya está registrado' } };
    }

    const userId = generateId();
    const newUser = {
      id: userId,
      email,
      password,
      full_name,
      role: 'cliente',
      created_at: new Date().toISOString()
    };

    const newInvestment = {
      id: generateId(),
      user_id: userId,
      inversion_actual: Number(inversion_actual),
      tasa_mensual: Number(tasa_mensual),
      ganancia_acumulada: 0,
      created_at: new Date().toISOString()
    };

    db.profiles.push(newUser);
    db.investments.push(newInvestment);
    saveDB(db);

    return { data: newUser, error: null };
  }
};
