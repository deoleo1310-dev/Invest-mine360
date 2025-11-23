# ⚡ Guía de Configuración de Supabase

Esta guía explica cómo conectar y configurar Supabase para InvestPro.

## 1. Crear Proyecto
1. Ve a [Supabase.com](https://supabase.com) y crea un nuevo proyecto.
2. Guarda la contraseña de la base de datos.

## 2. Obtener Credenciales
1. En el dashboard, ve a **Settings** (icono engranaje) -> **API**.
2. Copia la **Project URL**.
3. Copia la **anon public key**.
4. Pega estos valores en tu archivo `.env` en el proyecto local:
   ```env
   VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
   VITE_SUPABASE_ANON_KEY=tu-anon-key-larga
   ```

## 3. Configurar Base de Datos (Tablas)
Copia el siguiente script SQL y ejecútalo en el **SQL Editor** de Supabase:

*(El script completo se encuentra en `supabase/migrations/20250220143000_initial_setup.sql` en tu repositorio)*

Resumen de tablas creadas:
- `profiles`: Datos públicos del usuario (nombre, rol).
- `investments`: Información financiera (monto, tasa).
- `withdrawals`: Historial de solicitudes de retiro.

## 4. Configurar Primer Admin
Por seguridad, el registro público está deshabilitado o crea usuarios como 'cliente'. Para crear tu primer admin:
1. Ve a **Authentication** -> **Users** y crea un usuario (ej: admin@investpro.com).
2. Ve a **Table Editor** -> `profiles`.
3. Busca el usuario creado y cambia la columna `role` de `cliente` a `admin`.

## 5. Políticas de Seguridad (RLS)
El script SQL ya configura Row Level Security:
- **Admin**: Puede ver y editar TODO (usando políticas `true` para el rol admin).
- **Cliente**: Solo puede ver SU propio perfil, SU inversión y SUS retiros.
