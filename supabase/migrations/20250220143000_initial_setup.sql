/*
  # Esquema Inicial de InvestPro
  
  ## Estructura
  1. profiles: Extensión de auth.users para datos de perfil (rol, nombre).
  2. investments: Tabla para gestionar la inversión y tasa de cada usuario.
  3. withdrawals: Tabla para gestionar las solicitudes de retiro.
  
  ## Seguridad
  - RLS habilitado en todas las tablas.
  - Políticas para que los clientes solo vean sus datos.
  - Políticas para que los admins vean y editen todo.
*/

-- 1. Tabla de Perfiles (Vinculada a auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'cliente' CHECK (role IN ('admin', 'cliente')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabla de Inversiones
CREATE TABLE public.investments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  inversion_actual NUMERIC DEFAULT 0,
  tasa_mensual NUMERIC DEFAULT 0,
  ganancia_acumulada NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabla de Retiros
CREATE TABLE public.withdrawals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  monto NUMERIC NOT NULL,
  estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagado', 'rechazado')),
  fecha_solicitud TIMESTAMPTZ DEFAULT NOW(),
  fecha_procesado TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;

-- Políticas de Seguridad (RLS)

-- PROFILES
CREATE POLICY "Usuarios pueden ver su propio perfil" 
ON public.profiles FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Admins pueden ver todos los perfiles" 
ON public.profiles FOR SELECT 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins pueden actualizar perfiles" 
ON public.profiles FOR UPDATE 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- INVESTMENTS
CREATE POLICY "Usuarios pueden ver su propia inversión" 
ON public.investments FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Admins pueden ver todas las inversiones" 
ON public.investments FOR SELECT 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins pueden gestionar inversiones" 
ON public.investments FOR ALL 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- WITHDRAWALS
CREATE POLICY "Usuarios pueden ver sus retiros" 
ON public.withdrawals FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Usuarios pueden solicitar retiros" 
ON public.withdrawals FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins pueden ver todos los retiros" 
ON public.withdrawals FOR SELECT 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins pueden gestionar retiros" 
ON public.withdrawals FOR UPDATE 
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- TRIGGER AUTOMÁTICO: Crear perfil al registrarse en Auth
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'Usuario Nuevo'),
    COALESCE(new.raw_user_meta_data->>'role', 'cliente')
  );
  
  -- Crear registro de inversión vacío para el nuevo usuario
  INSERT INTO public.investments (user_id, inversion_actual, tasa_mensual)
  VALUES (new.id, 0, 0);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
