# 📘 InvestPro - Documentación del Proyecto

## Descripción General
InvestPro es una plataforma web de gestión de inversiones diseñada con un enfoque "Mobile-First". Permite a un administrador gestionar usuarios, inversiones y retiros, mientras que los clientes pueden visualizar sus ganancias en tiempo real y solicitar retiros.

## 🛠 Stack Tecnológico
- **Frontend**: React 18 + Vite
- **Estilos**: Tailwind CSS (Diseño Utility-First)
- **Iconos**: Lucide React
- **Base de Datos & Auth**: Supabase (PostgreSQL)
- **Routing**: React Router DOM

## 📂 Estructura del Proyecto

```
src/
├── components/         # Componentes Reutilizables
│   ├── layout/         # Layout principal (Header, Nav)
│   └── ui/             # UI Kit (Button, Card, Input, Modal, Badge)
├── context/            # Contexto Global (AuthContext)
├── lib/                # Configuración de Supabase y utilidades
├── pages/              # Vistas de la aplicación
│   ├── admin/          # Vistas de Administrador (Usuarios, Retiros)
│   ├── client/         # Vistas de Cliente (Dashboard)
│   └── Login.jsx       # Página de acceso
└── App.jsx             # Rutas y protección de vistas
```

## 🧩 Componentes Clave

### 1. AuthContext (`src/context/AuthContext.jsx`)
Maneja el estado global de la sesión. Escucha los cambios en `supabase.auth` y obtiene automáticamente el perfil del usuario desde la tabla `profiles` para determinar el rol (admin/cliente).

### 2. Layout (`src/components/layout/Layout.jsx`)
Define la estructura visual.
- **Header Azul**: Presente en todas las vistas.
- **Navegación Adaptativa**: Muestra pestañas en el header para Desktop y una barra inferior fija para Móviles.

### 3. Fake vs Real Supabase
El proyecto incluye una implementación real de Supabase en `src/lib/supabaseClient.js`. También existe un archivo `fakeSupabase.js` (ahora en desuso) que sirvió para prototipado inicial.

## 🚀 Flujos Principales

### Creación de Usuarios (Admin)
El administrador puede crear usuarios desde `src/pages/admin/Users.jsx`.
- Se utiliza un **Cliente Secundario** (`src/lib/adminAuthClient.js`) para registrar al usuario en `auth.users` sin cerrar la sesión del administrador.
- Se insertan registros en `profiles` y `investments` automáticamente.

### Solicitud de Retiros (Cliente)
- El cliente ve su ganancia calculada en tiempo real (Inversión * Tasa * Meses).
- Al solicitar retiro, se crea un registro en `withdrawals` con estado `pendiente`.

### Gestión de Retiros (Admin)
- El admin ve una lista filtrable de retiros.
- Al aprobar (`pagado`), el monto se considera "retirado" y se resta del cálculo de ganancia disponible del cliente.
