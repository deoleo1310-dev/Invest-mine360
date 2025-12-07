

// Tablas y columnas
table_name,column_name,data_type,is_nullable,column_default
daily_earnings,id,uuid,NO,gen_random_uuid()
daily_earnings,user_id,uuid,NO,null
daily_earnings,investment_id,uuid,NO,null
daily_earnings,investment_amount,numeric,NO,null
daily_earnings,daily_rate,numeric,NO,null
daily_earnings,earning_amount,numeric,NO,null
daily_earnings,date,date,NO,null
daily_earnings,created_at,timestamp with time zone,YES,now()
investments,id,uuid,NO,gen_random_uuid()
investments,user_id,uuid,NO,null
investments,inversion_actual,numeric,YES,0
investments,ganancia_acumulada,numeric,YES,0
investments,created_at,timestamp with time zone,YES,now()
investments,updated_at,timestamp with time zone,YES,now()
investments,last_week_generated,date,YES,null
investments,tasa_diaria,numeric,YES,0
profiles,id,uuid,NO,null
profiles,email,text,NO,null
profiles,full_name,text,YES,null
profiles,role,text,YES,'cliente'::text
profiles,created_at,timestamp with time zone,YES,now()
profiles,updated_at,timestamp with time zone,YES,now()
withdrawals,id,uuid,NO,gen_random_uuid()
withdrawals,user_id,uuid,NO,null
withdrawals,monto,numeric,NO,null
withdrawals,estado,text,YES,'pendiente'::text
withdrawals,fecha_solicitud,timestamp with time zone,YES,now()
withdrawals,fecha_procesado,timestamp with time zone,YES,null
withdrawals,created_at,timestamp with time zone,YES,now()


//policies 
schemaname,tablename,policyname,permissive,roles,command,using_expression,check_expression
public,daily_earnings,Admins ven todas las ganancias diarias,PERMISSIVE,{public},SELECT,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))",null
public,daily_earnings,Sistema inserta ganancias diarias,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)
public,daily_earnings,Usuarios ven sus ganancias diarias,PERMISSIVE,{public},SELECT,(auth.uid() = user_id),null
public,investments,admin_delete_investments,PERMISSIVE,{public},DELETE,is_admin(),null
public,investments,admin_insert_investments,PERMISSIVE,{public},INSERT,null,is_admin()
public,investments,admin_or_own_select_investments,PERMISSIVE,{public},SELECT,(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = user_id)),null
public,investments,admin_update_investments,PERMISSIVE,{public},UPDATE,is_admin(),is_admin()
public,profiles,admin_delete_profiles,PERMISSIVE,{public},DELETE,is_admin(),null
public,profiles,admin_insert_profiles,PERMISSIVE,{public},INSERT,null,(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = id))
public,profiles,admin_or_own_select_profiles,PERMISSIVE,{public},SELECT,(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = id)),null
public,profiles,admin_or_own_update_profiles,PERMISSIVE,{public},UPDATE,(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = id)),(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = id))
public,withdrawals,admin_delete_withdrawals,PERMISSIVE,{public},DELETE,is_admin(),null
public,withdrawals,admin_or_own_select_withdrawals,PERMISSIVE,{public},SELECT,(( SELECT is_admin() AS is_admin) OR (( SELECT auth.uid() AS uid) = user_id)),null
public,withdrawals,admin_update_withdrawals,PERMISSIVE,{public},UPDATE,is_admin(),is_admin()
public,withdrawals,user_insert_withdrawals,PERMISSIVE,{public},INSERT,null,(( SELECT auth.uid() AS uid) = user_id)



// indices
schema,table_name,index_name,index_definition,is_unique,is_primary
public,daily_earnings,daily_earnings_pkey,CREATE UNIQUE INDEX daily_earnings_pkey ON public.daily_earnings USING btree (id),true,true
public,daily_earnings,idx_daily_earnings_date,CREATE INDEX idx_daily_earnings_date ON public.daily_earnings USING btree (date DESC),false,false
public,daily_earnings,idx_daily_earnings_lookup,"CREATE INDEX idx_daily_earnings_lookup ON public.daily_earnings USING btree (user_id, date DESC) INCLUDE (earning_amount)",false,false
public,daily_earnings,idx_daily_earnings_user,CREATE INDEX idx_daily_earnings_user ON public.daily_earnings USING btree (user_id),false,false
public,daily_earnings,unique_user_day,"CREATE UNIQUE INDEX unique_user_day ON public.daily_earnings USING btree (user_id, date)",true,false
public,investments,idx_investments_created_at,CREATE INDEX idx_investments_created_at ON public.investments USING btree (created_at DESC),false,false
public,investments,idx_investments_user_created,"CREATE INDEX idx_investments_user_created ON public.investments USING btree (user_id, created_at DESC)",false,false
public,investments,investments_pkey,CREATE UNIQUE INDEX investments_pkey ON public.investments USING btree (id),true,true
public,profiles,idx_profiles_cliente_active,"CREATE INDEX idx_profiles_cliente_active ON public.profiles USING btree (id, email, created_at DESC) WHERE (role = 'cliente'::text)",false,false
public,profiles,idx_profiles_created_at,CREATE INDEX idx_profiles_created_at ON public.profiles USING btree (created_at DESC),false,false
public,profiles,idx_profiles_role,CREATE INDEX idx_profiles_role ON public.profiles USING btree (role),false,false
public,profiles,profiles_email_key,CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email),true,false
public,profiles,profiles_pkey,CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id),true,true
public,withdrawals,idx_withdrawals_estado,CREATE INDEX idx_withdrawals_estado ON public.withdrawals USING btree (estado),false,false
public,withdrawals,idx_withdrawals_estado_fecha,"CREATE INDEX idx_withdrawals_estado_fecha ON public.withdrawals USING btree (estado, fecha_solicitud DESC)",false,false
public,withdrawals,idx_withdrawals_fecha_solicitud,CREATE INDEX idx_withdrawals_fecha_solicitud ON public.withdrawals USING btree (fecha_solicitud DESC),false,false
public,withdrawals,idx_withdrawals_pending_only,"CREATE INDEX idx_withdrawals_pending_only ON public.withdrawals USING btree (user_id, monto, fecha_solicitud DESC) WHERE (estado = 'pendiente'::text)",false,false
public,withdrawals,idx_withdrawals_user_estado,"CREATE INDEX idx_withdrawals_user_estado ON public.withdrawals USING btree (user_id, estado)",false,false
public,withdrawals,idx_withdrawals_user_id,CREATE INDEX idx_withdrawals_user_id ON public.withdrawals USING btree (user_id),false,false
public,withdrawals,withdrawals_pkey,CREATE UNIQUE INDEX withdrawals_pkey ON public.withdrawals USING btree (id),true,true


// funciones

schema,function_name,arguments,return_type,definition
public,check_sufficient_funds,,trigger,"CREATE OR REPLACE FUNCTION public.check_sufficient_funds()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  available_funds NUMERIC;
BEGIN
  -- Calcular fondos disponibles usando la función actualizada
  SELECT public.get_available_balance(NEW.user_id) INTO available_funds;
  
  IF NEW.monto > available_funds THEN
    RAISE EXCEPTION 'Fondos insuficientes. Disponible: %', available_funds;
  END IF;
  
  RETURN NEW;
END;
$function$
"
public,generate_user_daily_earnings,p_user_id uuid,"TABLE(days_generated integer, total_earnings numeric, message text)","CREATE OR REPLACE FUNCTION public.generate_user_daily_earnings(p_user_id uuid)
 RETURNS TABLE(days_generated integer, total_earnings numeric, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_current_date DATE;
  v_days_generated INT := 0;
  v_total_earnings NUMERIC := 0;
  v_daily_earning NUMERIC;
  v_last_date DATE;
BEGIN
  -- Obtener inversión activa del usuario
  SELECT 
    i.id,
    i.user_id,
    i.inversion_actual,
    i.tasa_diaria,
    i.created_at,
    COALESCE(i.last_week_generated, (i.created_at)::DATE) as last_generated
  INTO v_investment
  FROM public.investments i
  WHERE i.user_id = p_user_id
    AND i.inversion_actual > 0
  LIMIT 1;

  -- Si no hay inversión activa
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0::NUMERIC, 'No hay inversión activa'::TEXT;
    RETURN;
  END IF;

  -- Última fecha generada
  v_last_date := v_investment.last_generated;
  
  -- Fecha de inicio: día siguiente al último generado
  v_current_date := v_last_date + INTERVAL '1 day';
  
  -- Generar ganancias SOLO hasta AYER (no incluir hoy)
  WHILE v_current_date < CURRENT_DATE LOOP
    
    -- Verificar que no exista ya
    IF NOT EXISTS (
      SELECT 1 FROM public.daily_earnings 
      WHERE user_id = p_user_id AND date = v_current_date
    ) THEN
      
      -- Calcular ganancia diaria
      v_daily_earning := v_investment.inversion_actual * (v_investment.tasa_diaria / 100);
      
      -- Insertar ganancia
      INSERT INTO public.daily_earnings (
        user_id,
        investment_id,
        investment_amount,
        daily_rate,
        earning_amount,
        date
      ) VALUES (
        v_investment.user_id,
        v_investment.id,
        v_investment.inversion_actual,
        v_investment.tasa_diaria,
        v_daily_earning,
        v_current_date
      );
      
      v_days_generated := v_days_generated + 1;
      v_total_earnings := v_total_earnings + v_daily_earning;
    END IF;
    
    -- Avanzar al siguiente día
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;

  -- Actualizar última fecha generada
  IF v_days_generated > 0 THEN
    UPDATE public.investments 
    SET last_week_generated = CURRENT_DATE - INTERVAL '1 day'
    WHERE id = v_investment.id;
  END IF;

  -- Retornar resultado
  RETURN QUERY SELECT 
    v_days_generated, 
    v_total_earnings,
    CASE 
      WHEN v_days_generated > 0 THEN 'Ganancias diarias generadas exitosamente'
      ELSE 'No hay días nuevos para generar'
    END::TEXT;
END;
$function$
"
public,generate_user_weekly_earnings,p_user_id uuid,"TABLE(weeks_generated integer, total_earnings numeric, message text)","CREATE OR REPLACE FUNCTION public.generate_user_weekly_earnings(p_user_id uuid)
 RETURNS TABLE(weeks_generated integer, total_earnings numeric, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_week_start DATE;
  v_week_end DATE;
  v_weeks_generated INT := 0;
  v_total_earnings NUMERIC := 0;
  v_weekly_rate NUMERIC;
  v_earning NUMERIC;
  v_current_week_start DATE;
BEGIN
  -- Obtener inversión activa del usuario
  SELECT 
    i.id,
    i.user_id,
    i.inversion_actual,
    i.tasa_mensual,
    i.created_at,
    COALESCE(i.last_week_generated, DATE_TRUNC('week', i.created_at)::DATE) as last_generated
  INTO v_investment
  FROM public.investments i
  WHERE i.user_id = p_user_id
    AND i.inversion_actual > 0
  LIMIT 1;

  -- Si no hay inversión, retornar
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0::NUMERIC, 'No hay inversión activa'::TEXT;
    RETURN;
  END IF;

  -- Calcular inicio de semana actual (lunes)
  v_current_week_start := DATE_TRUNC('week', NOW())::DATE;
  
  -- Empezar desde la última semana generada + 1 semana
  v_week_start := v_investment.last_generated + INTERVAL '1 week';
  
  -- Generar ganancias para todas las semanas completas hasta la semana pasada
  -- (NO incluir la semana actual porque aún no terminó)
  WHILE v_week_start < v_current_week_start LOOP
    v_week_end := v_week_start + INTERVAL '6 days';
    
    -- Verificar que esta semana no exista ya
    IF NOT EXISTS (
      SELECT 1 FROM public.weekly_earnings 
      WHERE user_id = p_user_id AND week_start = v_week_start
    ) THEN
      -- Calcular ganancia semanal
      v_weekly_rate := v_investment.tasa_mensual / 4;
      v_earning := v_investment.inversion_actual * (v_weekly_rate / 100);
      
      -- Insertar ganancia
      INSERT INTO public.weekly_earnings (
        user_id,
        investment_id,
        investment_amount,
        weekly_rate,
        earning_amount,
        week_start,
        week_end
      ) VALUES (
        v_investment.user_id,
        v_investment.id,
        v_investment.inversion_actual,
        v_weekly_rate,
        v_earning,
        v_week_start,
        v_week_end
      );
      
      v_weeks_generated := v_weeks_generated + 1;
      v_total_earnings := v_total_earnings + v_earning;
    END IF;
    
    -- Avanzar a la siguiente semana
    v_week_start := v_week_start + INTERVAL '1 week';
  END LOOP;

  -- Actualizar última semana generada
  IF v_weeks_generated > 0 THEN
    UPDATE public.investments 
    SET last_week_generated = v_week_start - INTERVAL '1 week'
    WHERE id = v_investment.id;
  END IF;

  -- Retornar resultado
  RETURN QUERY SELECT 
    v_weeks_generated, 
    v_total_earnings,
    CASE 
      WHEN v_weeks_generated > 0 THEN 'Ganancias generadas exitosamente'
      ELSE 'No hay semanas nuevas para generar'
    END::TEXT;
END;
$function$
"
public,get_available_balance,p_user_id uuid,numeric,"CREATE OR REPLACE FUNCTION public.get_available_balance(p_user_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total_earnings NUMERIC;
  v_total_withdrawals NUMERIC;
  v_pending_withdrawals NUMERIC;
BEGIN
  -- Sumar todas las ganancias diarias
  SELECT COALESCE(SUM(earning_amount), 0) 
  INTO v_total_earnings
  FROM public.daily_earnings
  WHERE user_id = p_user_id;
  
  -- Sumar retiros pagados
  SELECT COALESCE(SUM(monto), 0)
  INTO v_total_withdrawals
  FROM public.withdrawals
  WHERE user_id = p_user_id AND estado = 'pagado';
  
  -- Sumar retiros pendientes (fondos reservados)
  SELECT COALESCE(SUM(monto), 0)
  INTO v_pending_withdrawals
  FROM public.withdrawals
  WHERE user_id = p_user_id AND estado = 'pendiente';
  
  RETURN GREATEST(v_total_earnings - v_total_withdrawals - v_pending_withdrawals, 0);
END;
$function$
"
public,get_current_week_projection,p_user_id uuid,numeric,"CREATE OR REPLACE FUNCTION public.get_current_week_projection(p_user_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_weekly_rate NUMERIC;
  v_days_elapsed INT;
  v_projection NUMERIC;
BEGIN
  -- Obtener inversión activa
  SELECT inversion_actual, tasa_mensual
  INTO v_investment
  FROM public.investments
  WHERE user_id = p_user_id
  LIMIT 1;
  
  IF NOT FOUND OR v_investment.inversion_actual = 0 THEN
    RETURN 0;
  END IF;
  
  -- Calcular tasa semanal
  v_weekly_rate := v_investment.tasa_mensual / 4;
  
  -- Calcular días transcurridos en la semana actual
  v_days_elapsed := EXTRACT(DOW FROM NOW()); -- 0=domingo, 1=lunes, etc.
  IF v_days_elapsed = 0 THEN v_days_elapsed := 7; END IF;
  
  -- Proyección proporcional a los días transcurridos
  v_projection := v_investment.inversion_actual * (v_weekly_rate / 100) * (v_days_elapsed / 7.0);
  
  RETURN v_projection;
END;
$function$
"
public,get_user_role,,text,"CREATE OR REPLACE FUNCTION public.get_user_role()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$function$
"
public,get_user_total_earnings,p_user_id uuid,"TABLE(total_earnings numeric, days_count integer, daily_rate numeric, current_investment numeric)","CREATE OR REPLACE FUNCTION public.get_user_total_earnings(p_user_id uuid)
 RETURNS TABLE(total_earnings numeric, days_count integer, daily_rate numeric, current_investment numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_total_gain NUMERIC;
  v_days INT;
BEGIN
  -- Obtener inversión activa
  SELECT 
    inversion_actual,
    tasa_diaria,
    created_at
  INTO v_investment
  FROM public.investments
  WHERE user_id = p_user_id
  LIMIT 1;
  
  -- Si no hay inversión
  IF NOT FOUND OR v_investment.inversion_actual = 0 THEN
    RETURN QUERY SELECT 
      0::NUMERIC as total_earnings,
      0 as days_count,
      0::NUMERIC as daily_rate,
      0::NUMERIC as current_investment;
    RETURN;
  END IF;
  
  -- Sumar todas las ganancias diarias generadas
  SELECT 
    COALESCE(SUM(earning_amount), 0),
    COALESCE(COUNT(*), 0)
  INTO v_total_gain, v_days
  FROM public.daily_earnings
  WHERE user_id = p_user_id;
  
  -- Retornar datos completos
  RETURN QUERY SELECT 
    COALESCE(v_total_gain, 0)::NUMERIC,
    v_days,
    v_investment.tasa_diaria::NUMERIC,
    v_investment.inversion_actual;
END;
$function$
"
public,handle_new_user,,trigger,"CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'Usuario Nuevo'),
    COALESCE(new.raw_user_meta_data->>'role', 'cliente')
  );
  
  RETURN new;
END;
$function$
"
public,initialize_investment,,trigger,"CREATE OR REPLACE FUNCTION public.initialize_investment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Establecer la fecha de inicio como AYER (último día generado)
  NEW.last_week_generated := (CURRENT_DATE - INTERVAL '1 day')::DATE;
  RETURN NEW;
END;
$function$
"
public,is_admin,,boolean,"CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$
"

/triggers 
trigger_name,table_name,trigger_definition
on_investment_created,investments,CREATE TRIGGER on_investment_created BEFORE INSERT ON investments FOR EACH ROW EXECUTE FUNCTION initialize_investment()





//  foreing keys y constraints
table_name,constraint_name,constraint_type,column_name,foreign_table,foreign_column
daily_earnings,2200_34624_1_not_null,CHECK,null,null,null
daily_earnings,2200_34624_7_not_null,CHECK,null,null,null
daily_earnings,2200_34624_6_not_null,CHECK,null,null,null
daily_earnings,2200_34624_5_not_null,CHECK,null,null,null
daily_earnings,2200_34624_4_not_null,CHECK,null,null,null
daily_earnings,2200_34624_3_not_null,CHECK,null,null,null
daily_earnings,2200_34624_2_not_null,CHECK,null,null,null
daily_earnings,daily_earnings_investment_id_fkey,FOREIGN KEY,investment_id,investments,id
daily_earnings,daily_earnings_user_id_fkey,FOREIGN KEY,user_id,profiles,id
daily_earnings,daily_earnings_pkey,PRIMARY KEY,id,daily_earnings,id
daily_earnings,unique_user_day,UNIQUE,date,daily_earnings,user_id
daily_earnings,unique_user_day,UNIQUE,user_id,daily_earnings,date
daily_earnings,unique_user_day,UNIQUE,user_id,daily_earnings,user_id
daily_earnings,unique_user_day,UNIQUE,date,daily_earnings,date
investments,2200_17505_1_not_null,CHECK,null,null,null
investments,2200_17505_2_not_null,CHECK,null,null,null
investments,investments_user_id_fkey,FOREIGN KEY,user_id,profiles,id
investments,investments_pkey,PRIMARY KEY,id,investments,id
profiles,profiles_role_check,CHECK,null,profiles,role
profiles,2200_17487_1_not_null,CHECK,null,null,null
profiles,2200_17487_2_not_null,CHECK,null,null,null
profiles,profiles_id_fkey,FOREIGN KEY,id,null,null
profiles,profiles_pkey,PRIMARY KEY,id,profiles,id
profiles,profiles_email_key,UNIQUE,email,profiles,email
withdrawals,withdrawals_estado_check,CHECK,null,withdrawals,estado
withdrawals,2200_17523_3_not_null,CHECK,null,null,null
withdrawals,2200_17523_1_not_null,CHECK,null,null,null
withdrawals,2200_17523_2_not_null,CHECK,null,null,null
withdrawals,withdrawals_user_id_fkey,FOREIGN KEY,user_id,profiles,id
withdrawals,withdrawals_pkey,PRIMARY KEY,id,withdrawals,id