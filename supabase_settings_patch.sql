-- ============================================================
-- PARCHE SQL: CONFIGURACIÓN GLOBAL DE LA APLICACIÓN (Settings)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================

CREATE TABLE public.app_settings (
  id BOOLEAN PRIMARY KEY DEFAULT true CHECK (id = true), -- Asegura que solo exista 1 fila global
  app_name TEXT NOT NULL DEFAULT 'Mine360pr',
  paypal_link TEXT NOT NULL DEFAULT 'https://paypal.me/tuusuario',
  whatsapp_link TEXT,
  primary_color TEXT NOT NULL DEFAULT '#1464F4',
  secondary_color TEXT NOT NULL DEFAULT '#0A2A6E',
  default_rate_value NUMERIC NOT NULL DEFAULT 15,
  default_rate_period TEXT NOT NULL DEFAULT 'mensual' CHECK (default_rate_period IN ('diaria', 'semanal', 'mensual')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insertar configuración por defecto evitando duplicados
INSERT INTO public.app_settings (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

-- Trigger para auto-actualizar updated_at
CREATE OR REPLACE FUNCTION public.update_app_settings_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_app_settings_update
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION update_app_settings_timestamp();

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Lectura pública (Necesario para que el Login tenga los colores antes de auth)
CREATE POLICY settings_select ON public.app_settings
  FOR SELECT USING (true);

-- Edición solo admin
CREATE POLICY settings_update ON public.app_settings
  FOR UPDATE USING (is_admin());

-- Inserción solo admin (defensa si la fila se borra accidentalmente)
CREATE POLICY settings_insert ON public.app_settings
  FOR INSERT WITH CHECK (is_admin());

-- ============================================================
-- FUNCIÓN DE NORMALIZACIÓN MATEMÁTICA
-- ============================================================

-- Convierte cualquier tasa (mensual/semanal) a su equivalente diario
-- Ejemplo: normalize_to_daily_rate(10, 'mensual') = 0.3333...
CREATE OR REPLACE FUNCTION public.normalize_to_daily_rate(rate_value NUMERIC, period TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF period = 'mensual' THEN
    RETURN rate_value / 30.0;
  ELSIF period = 'semanal' THEN
    RETURN rate_value / 7.0;
  ELSE
    RETURN rate_value; -- 'diaria'
  END IF;
END;
$$;
