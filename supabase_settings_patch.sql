-- ============================================================
-- PARCHE SQL: CONFIGURACIÓN GLOBAL DE LA APLICACIÓN (Settings)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================

CREATE TABLE public.app_settings (
  id BOOLEAN PRIMARY KEY DEFAULT true CHECK (id = true), -- Asegura que solo exista 1 fila global
  app_name TEXT NOT NULL DEFAULT 'Mine360pr',
  paypal_link TEXT NOT NULL DEFAULT 'https://paypal.me/tuusuario',
  whatsapp_link TEXT,
  primary_color TEXT NOT NULL DEFAULT '#D4AF37', -- Oro oscuro
  secondary_color TEXT NOT NULL DEFAULT '#1A1A1A', -- Negro
  default_rate_value NUMERIC NOT NULL DEFAULT 15,
  default_rate_period TEXT NOT NULL DEFAULT 'mensual' CHECK (default_rate_period IN ('diaria', 'semanal', 'mensual')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insertar configuración por defecto evitando duplicados
INSERT INTO public.app_settings (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Lectura pública (Necesario para que el Login tenga el logo y colores antes de auth)
CREATE POLICY settings_select ON public.app_settings
  FOR SELECT USING (true);

-- Edición solo admin
CREATE POLICY settings_update ON public.app_settings
  FOR UPDATE USING (is_admin());

-- ============================================================
-- FUNCIONES DE NORMALIZACIÓN MATEMÁTICA
-- ============================================================

-- Toma cualquier tasa (mensual/semanal) y la divide para el motor central de ganancias
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
