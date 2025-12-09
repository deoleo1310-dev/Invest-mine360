// supabase tablas y columnas 

table_name,column_name,data_type,is_nullable,column_default
daily_earnings,id,uuid,NO,gen_random_uuid()
daily_earnings,user_id,uuid,NO,null
daily_earnings,investment_id,uuid,NO,null
daily_earnings,investment_amount,numeric,NO,null
daily_earnings,daily_rate,numeric,NO,null
daily_earnings,earning_amount,numeric,NO,null
daily_earnings,date,date,NO,null
daily_earnings,created_at,timestamp with time zone,YES,now()
investment_history,id,uuid,NO,gen_random_uuid()
investment_history,user_id,uuid,NO,null
investment_history,investment_id,uuid,NO,null
investment_history,amount,numeric,NO,null
investment_history,daily_rate,numeric,NO,null
investment_history,effective_date,date,NO,CURRENT_DATE
investment_history,created_at,timestamp with time zone,YES,now()
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

//supabase indices

table_name,index_name,index_definition,is_unique,is_primary
daily_earnings,daily_earnings_pkey,CREATE UNIQUE INDEX daily_earnings_pkey ON public.daily_earnings USING btree (id),true,true
daily_earnings,idx_daily_earnings_lookup,"CREATE INDEX idx_daily_earnings_lookup ON public.daily_earnings USING btree (user_id, date DESC) INCLUDE (earning_amount)",false,false
daily_earnings,idx_daily_earnings_user_date,"CREATE INDEX idx_daily_earnings_user_date ON public.daily_earnings USING btree (user_id, date DESC)",false,false
daily_earnings,idx_daily_earnings_user_date_earning,"CREATE INDEX idx_daily_earnings_user_date_earning ON public.daily_earnings USING btree (user_id, date DESC) INCLUDE (earning_amount)",false,false
daily_earnings,idx_daily_earnings_user_sum,CREATE INDEX idx_daily_earnings_user_sum ON public.daily_earnings USING btree (user_id) INCLUDE (earning_amount),false,false
daily_earnings,idx_daily_earnings_user_sum_optimized,CREATE INDEX idx_daily_earnings_user_sum_optimized ON public.daily_earnings USING btree (user_id) INCLUDE (earning_amount) WHERE (earning_amount > (0)::numeric),false,false
daily_earnings,idx_daily_earnings_user_summary,CREATE INDEX idx_daily_earnings_user_summary ON public.daily_earnings USING btree (user_id) INCLUDE (earning_amount),false,false
daily_earnings,unique_user_day,"CREATE UNIQUE INDEX unique_user_day ON public.daily_earnings USING btree (user_id, date)",true,false
investment_history,idx_investment_history_date,CREATE INDEX idx_investment_history_date ON public.investment_history USING btree (effective_date DESC),false,false
investment_history,idx_investment_history_investment,CREATE INDEX idx_investment_history_investment ON public.investment_history USING btree (investment_id),false,false
investment_history,idx_investment_history_user,CREATE INDEX idx_investment_history_user ON public.investment_history USING btree (user_id),false,false
investment_history,investment_history_pkey,CREATE UNIQUE INDEX investment_history_pkey ON public.investment_history USING btree (id),true,true
investment_history,unique_investment_date,"CREATE UNIQUE INDEX unique_investment_date ON public.investment_history USING btree (investment_id, effective_date)",true,false
investments,idx_investments_created_at,CREATE INDEX idx_investments_created_at ON public.investments USING btree (created_at DESC),false,false
investments,idx_investments_user_active,"CREATE INDEX idx_investments_user_active ON public.investments USING btree (user_id, inversion_actual) WHERE (inversion_actual > (0)::numeric)",false,false
investments,investments_pkey,CREATE UNIQUE INDEX investments_pkey ON public.investments USING btree (id),true,true
profiles,idx_profiles_auth_role,"CREATE INDEX idx_profiles_auth_role ON public.profiles USING btree (id, role) WHERE (role = 'admin'::text)",false,false
profiles,idx_profiles_cliente_active,"CREATE INDEX idx_profiles_cliente_active ON public.profiles USING btree (id, email, created_at DESC) WHERE (role = 'cliente'::text)",false,false
profiles,idx_profiles_email_role,"CREATE INDEX idx_profiles_email_role ON public.profiles USING btree (email, role)",false,false
profiles,idx_profiles_lookup,"CREATE INDEX idx_profiles_lookup ON public.profiles USING btree (id) INCLUDE (full_name, email)",false,false
profiles,profiles_email_key,CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email),true,false
profiles,profiles_pkey,CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id),true,true
withdrawals,idx_withdrawals_balance_lookup,"CREATE INDEX idx_withdrawals_balance_lookup ON public.withdrawals USING btree (user_id, estado, fecha_solicitud DESC) INCLUDE (monto)",false,false
withdrawals,idx_withdrawals_estado,CREATE INDEX idx_withdrawals_estado ON public.withdrawals USING btree (estado),false,false
withdrawals,idx_withdrawals_estado_created,"CREATE INDEX idx_withdrawals_estado_created ON public.withdrawals USING btree (estado, created_at DESC) INCLUDE (user_id, monto)",false,false
withdrawals,idx_withdrawals_estado_fecha,"CREATE INDEX idx_withdrawals_estado_fecha ON public.withdrawals USING btree (estado, fecha_solicitud DESC)",false,false
withdrawals,idx_withdrawals_fecha_solicitud,CREATE INDEX idx_withdrawals_fecha_solicitud ON public.withdrawals USING btree (fecha_solicitud DESC),false,false
withdrawals,idx_withdrawals_pending_only,"CREATE INDEX idx_withdrawals_pending_only ON public.withdrawals USING btree (user_id, monto, fecha_solicitud DESC) WHERE (estado = 'pendiente'::text)",false,false
withdrawals,idx_withdrawals_user_estado_monto,"CREATE INDEX idx_withdrawals_user_estado_monto ON public.withdrawals USING btree (user_id, estado, monto)",false,false
withdrawals,idx_withdrawals_user_recent,"CREATE INDEX idx_withdrawals_user_recent ON public.withdrawals USING btree (user_id, fecha_solicitud DESC) INCLUDE (monto, estado)",false,false
withdrawals,withdrawals_pkey,CREATE UNIQUE INDEX withdrawals_pkey ON public.withdrawals USING btree (id),true,true


/// supabase policies 

schemaname,tablename,policyname,permissive,roles,command,using_expression,check_expression
public,daily_earnings,Admins ven todas las ganancias diarias,PERMISSIVE,{public},SELECT,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))",null
public,daily_earnings,Sistema inserta ganancias diarias,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)
public,daily_earnings,Usuarios ven sus ganancias diarias,PERMISSIVE,{public},SELECT,(auth.uid() = user_id),null
public,investment_history,Admins can view all history,PERMISSIVE,{public},SELECT,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))",null
public,investment_history,System can insert history,PERMISSIVE,{public},INSERT,null,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))"
public,investment_history,Users can view their own history,PERMISSIVE,{public},SELECT,(auth.uid() = user_id),null
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

///supabase triggers

table_name,trigger_name,event,action_timing,action_statement
investments,investment_history_trigger,INSERT,AFTER,EXECUTE FUNCTION log_investment_change()
investments,investment_history_trigger,UPDATE,AFTER,EXECUTE FUNCTION log_investment_change()
investments,on_investment_created,INSERT,BEFORE,EXECUTE FUNCTION initialize_investment()


/// supabase triggers mas funciones 

trigger_name,trigger_definition
update_objects_updated_at,CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column()
prefixes_create_hierarchy,CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN (pg_trigger_depth() < 1) EXECUTE FUNCTION storage.prefixes_insert_trigger()
enforce_bucket_name_length_trigger,CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length()
objects_insert_create_prefix,CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger()
objects_delete_delete_prefix,CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger()
objects_update_create_prefix,CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (new.name <> old.name OR new.bucket_id <> old.bucket_id) EXECUTE FUNCTION storage.objects_update_prefix_trigger()
prefixes_delete_hierarchy,CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger()
tr_check_filters,CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters()
on_auth_user_created,CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()
on_investment_created,CREATE TRIGGER on_investment_created BEFORE INSERT ON investments FOR EACH ROW EXECUTE FUNCTION initialize_investment()
investment_history_trigger,CREATE TRIGGER investment_history_trigger AFTER INSERT OR UPDATE ON investments FOR EACH ROW EXECUTE FUNCTION log_investment_change()

///supabase funciones 

function_name,schema,definition
calculate_withdrawal_balance,public,"CREATE OR REPLACE FUNCTION public.calculate_withdrawal_balance(p_user_id uuid, p_exclude_withdrawal_id uuid DEFAULT NULL::uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  total_earned NUMERIC;
  total_paid NUMERIC;
  total_pending NUMERIC;
BEGIN
  -- Ganancias desde daily_earnings
  SELECT COALESCE(SUM(earning_amount), 0)
  INTO total_earned
  FROM daily_earnings
  WHERE user_id = p_user_id;
  
  -- Retiros pagados
  SELECT COALESCE(SUM(monto), 0)
  INTO total_paid
  FROM withdrawals
  WHERE user_id = p_user_id 
    AND estado = 'pagado';
  
  -- Retiros pendientes (excluyendo el actual)
  SELECT COALESCE(SUM(monto), 0)
  INTO total_pending
  FROM withdrawals
  WHERE user_id = p_user_id 
    AND estado = 'pendiente'
    AND (p_exclude_withdrawal_id IS NULL OR id != p_exclude_withdrawal_id);
  
  RETURN GREATEST(0, total_earned - total_paid - total_pending);
END;
$function$
"
check_sufficient_funds,public,"CREATE OR REPLACE FUNCTION public.check_sufficient_funds()
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
generate_daily_earnings,public,"CREATE OR REPLACE FUNCTION public.generate_daily_earnings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  inv RECORD;
  today DATE := CURRENT_DATE;
BEGIN
  FOR inv IN 
    SELECT 
      i.id AS investment_id,
      i.user_id,
      i.inversion_actual,
      i.tasa_diaria
    FROM investments i
    WHERE i.inversion_actual > 0
      AND i.tasa_diaria > 0
  LOOP
    INSERT INTO daily_earnings (
      user_id,
      investment_id,
      investment_amount,
      daily_rate,
      earning_amount,
      date
    )
    VALUES (
      inv.user_id,
      inv.investment_id,
      inv.inversion_actual,
      inv.tasa_diaria,
      inv.inversion_actual * (inv.tasa_diaria / 100),
      today
    )
    ON CONFLICT (user_id, date) DO NOTHING;
  END LOOP;
  
  RAISE NOTICE 'Ganancias generadas para %', today;
END;
$function$
"
generate_user_daily_earnings,public,"CREATE OR REPLACE FUNCTION public.generate_user_daily_earnings(p_user_id uuid)
 RETURNS TABLE(days_generated integer, total_earnings numeric, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_last_date DATE;
  v_days_generated INT;
  v_total_earnings NUMERIC;
BEGIN
  -- Obtener inversión
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

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0::NUMERIC, 'No hay inversión activa'::TEXT;
    RETURN;
  END IF;

  v_last_date := v_investment.last_generated;

  -- 🔥 INSERT MASIVO usando investment_history
  WITH date_series AS (
    SELECT generate_series(
      v_last_date + INTERVAL '1 day',
      CURRENT_DATE - INTERVAL '1 day',
      INTERVAL '1 day'
    )::DATE AS earning_date
  ),
  -- Obtener el monto y tasa correctos para cada día
  daily_rates AS (
    SELECT 
      ds.earning_date,
      COALESCE(
        (SELECT amount FROM public.investment_history 
         WHERE investment_id = v_investment.id 
           AND effective_date <= ds.earning_date
         ORDER BY effective_date DESC 
         LIMIT 1),
        v_investment.inversion_actual
      ) as amount,
      COALESCE(
        (SELECT daily_rate FROM public.investment_history 
         WHERE investment_id = v_investment.id 
           AND effective_date <= ds.earning_date
         ORDER BY effective_date DESC 
         LIMIT 1),
        v_investment.tasa_diaria
      ) as rate
    FROM date_series ds
  )
  INSERT INTO public.daily_earnings (
    user_id,
    investment_id,
    investment_amount,
    daily_rate,
    earning_amount,
    date
  )
  SELECT 
    v_investment.user_id,
    v_investment.id,
    dr.amount,
    dr.rate,
    dr.amount * (dr.rate / 100),
    dr.earning_date
  FROM daily_rates dr
  WHERE NOT EXISTS (
    SELECT 1 FROM public.daily_earnings de
    WHERE de.user_id = v_investment.user_id 
      AND de.date = dr.earning_date
  );

  GET DIAGNOSTICS v_days_generated = ROW_COUNT;
  
  v_total_earnings := (
    SELECT SUM(earning_amount) 
    FROM public.daily_earnings 
    WHERE user_id = v_investment.user_id
      AND date > v_last_date
      AND date < CURRENT_DATE
  );

  -- Actualizar última fecha
  IF v_days_generated > 0 THEN
    UPDATE public.investments 
    SET last_week_generated = CURRENT_DATE - INTERVAL '1 day'
    WHERE id = v_investment.id;
  END IF;

  RETURN QUERY SELECT 
    v_days_generated::INTEGER, 
    COALESCE(v_total_earnings, 0)::NUMERIC,
    CASE 
      WHEN v_days_generated > 0 THEN 'Ganancias generadas exitosamente'
      ELSE 'No hay días nuevos para generar'
    END::TEXT;
END;
$function$
"
generate_user_weekly_earnings,public,"CREATE OR REPLACE FUNCTION public.generate_user_weekly_earnings(p_user_id uuid)
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
get_all_clients_with_investments,public,"CREATE OR REPLACE FUNCTION public.get_all_clients_with_investments()
 RETURNS TABLE(user_id uuid, full_name text, email text, investment_id uuid, investment_amount numeric, daily_rate numeric, total_earnings numeric, days_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT 
    p.id AS user_id,
    p.full_name,
    p.email,
    i.id AS investment_id,
    COALESCE(i.inversion_actual, 0) AS investment_amount,
    COALESCE(i.tasa_diaria, 0) AS daily_rate,
    COALESCE(SUM(de.earning_amount), 0) AS total_earnings,
    COALESCE(COUNT(DISTINCT de.date), 0)::INTEGER AS days_count
  FROM profiles p
  LEFT JOIN investments i ON i.user_id = p.id
  LEFT JOIN daily_earnings de ON de.user_id = p.id
  WHERE p.role = 'cliente'
  GROUP BY p.id, p.full_name, p.email, i.id, i.inversion_actual, i.tasa_diaria
  ORDER BY p.created_at DESC;
$function$
"
get_client_dashboard_data,public,"CREATE OR REPLACE FUNCTION public.get_client_dashboard_data(p_user_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT json_build_object(
    'investment', (
      SELECT json_build_object(
        'id', i.id,
        'inversion_actual', i.inversion_actual,
        'tasa_diaria', i.tasa_diaria,
        'created_at', i.created_at
      )
      FROM investments i
      WHERE i.user_id = p_user_id
      LIMIT 1
    ),
    'withdrawals', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id', w.id,
          'monto', w.monto,
          'estado', w.estado,
          'fecha_solicitud', w.fecha_solicitud
        ) ORDER BY w.fecha_solicitud DESC
      ), '[]'::json)
      FROM withdrawals w
      WHERE w.user_id = p_user_id
      LIMIT 20 -- ✅ LIMITAR A 20 RETIROS RECIENTES
    ),
    'total_earnings', (
      SELECT COALESCE(SUM(earning_amount), 0)
      FROM daily_earnings
      WHERE user_id = p_user_id
    ),
    'available_balance', (
      SELECT GREATEST(0, 
        COALESCE(SUM(de.earning_amount), 0) - 
        COALESCE((
          SELECT SUM(monto) 
          FROM withdrawals 
          WHERE user_id = p_user_id 
            AND estado IN ('pagado', 'pendiente')
        ), 0)
      )
      FROM daily_earnings de
      WHERE de.user_id = p_user_id
    )
  );
$function$
"
get_current_week_projection,public,"CREATE OR REPLACE FUNCTION public.get_current_week_projection(p_user_id uuid)
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
get_system_metrics,public,"CREATE OR REPLACE FUNCTION public.get_system_metrics()
 RETURNS TABLE(metric text, value text, status text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    'Database Size'::TEXT,
    pg_size_pretty(pg_database_size(current_database()))::TEXT,
    CASE 
      WHEN pg_database_size(current_database()) > 450*1024*1024 
      THEN '⚠️ WARNING' 
      ELSE '✅ OK' 
    END::TEXT
  UNION ALL
  SELECT 
    'Active Connections',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) > 10 
      THEN '⚠️ HIGH' 
      ELSE '✅ OK' 
    END
  FROM pg_stat_activity
  WHERE datname = current_database()
  UNION ALL
  SELECT 
    'Pending Withdrawals',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) > 20 
      THEN '⚠️ REVIEW' 
      ELSE '✅ OK' 
    END
  FROM withdrawals
  WHERE estado = 'pendiente'
  UNION ALL
  SELECT 
    'Daily Earnings Today',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) = 0 
      THEN '❌ ERROR' 
      ELSE '✅ OK' 
    END
  FROM daily_earnings
  WHERE date = CURRENT_DATE;
END;
$function$
"
get_user_role,public,"CREATE OR REPLACE FUNCTION public.get_user_role()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$function$
"
get_user_total_earnings,public,"CREATE OR REPLACE FUNCTION public.get_user_total_earnings(p_user_id uuid)
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
get_withdrawals_with_balances,public,"CREATE OR REPLACE FUNCTION public.get_withdrawals_with_balances()
 RETURNS TABLE(withdrawal_id uuid, user_id uuid, user_name text, user_email text, monto numeric, estado text, fecha_solicitud timestamp with time zone, available_balance numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    w.id AS withdrawal_id,
    w.user_id,
    p.full_name AS user_name,
    p.email AS user_email,
    w.monto,
    w.estado,
    w.fecha_solicitud,
    GREATEST(0, 
      COALESCE(SUM(de.earning_amount), 0) - 
      COALESCE((
        SELECT SUM(monto) 
        FROM withdrawals 
        WHERE user_id = w.user_id 
          AND estado IN ('pagado', 'pendiente')
          AND id != w.id -- Excluir el retiro actual
      ), 0)
    ) AS available_balance
  FROM withdrawals w
  INNER JOIN profiles p ON p.id = w.user_id
  LEFT JOIN daily_earnings de ON de.user_id = w.user_id
  GROUP BY w.id, w.user_id, p.full_name, p.email, w.monto, w.estado, w.fecha_solicitud
  ORDER BY w.fecha_solicitud DESC;
END;
$function$
"
handle_new_user,public,"CREATE OR REPLACE FUNCTION public.handle_new_user()
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
initialize_investment,public,"CREATE OR REPLACE FUNCTION public.initialize_investment()
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
is_admin,public,"CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT EXISTS (
    SELECT 1 
    FROM profiles 
    WHERE id = auth.uid() 
      AND role = 'admin'
  );
$function$
"
log_investment_change,public,"CREATE OR REPLACE FUNCTION public.log_investment_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Solo registrar si cambia el monto o la tasa
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       NEW.inversion_actual != OLD.inversion_actual OR 
       NEW.tasa_diaria != OLD.tasa_diaria
     )) THEN
    
    -- Insertar snapshot del cambio
    INSERT INTO public.investment_history (
      user_id,
      investment_id,
      amount,
      daily_rate,
      effective_date
    ) VALUES (
      NEW.user_id,
      NEW.id,
      NEW.inversion_actual,
      NEW.tasa_diaria,
      CURRENT_DATE
    )
    ON CONFLICT (investment_id, effective_date) 
    DO UPDATE SET 
      amount = EXCLUDED.amount,
      daily_rate = EXCLUDED.daily_rate;
  END IF;
  
  RETURN NEW;
END;
$function$
"

//supabase funciones_rpc

rpc_name,definition
calculate_withdrawal_balance,"CREATE OR REPLACE FUNCTION public.calculate_withdrawal_balance(p_user_id uuid, p_exclude_withdrawal_id uuid DEFAULT NULL::uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  total_earned NUMERIC;
  total_paid NUMERIC;
  total_pending NUMERIC;
BEGIN
  -- Ganancias desde daily_earnings
  SELECT COALESCE(SUM(earning_amount), 0)
  INTO total_earned
  FROM daily_earnings
  WHERE user_id = p_user_id;
  
  -- Retiros pagados
  SELECT COALESCE(SUM(monto), 0)
  INTO total_paid
  FROM withdrawals
  WHERE user_id = p_user_id 
    AND estado = 'pagado';
  
  -- Retiros pendientes (excluyendo el actual)
  SELECT COALESCE(SUM(monto), 0)
  INTO total_pending
  FROM withdrawals
  WHERE user_id = p_user_id 
    AND estado = 'pendiente'
    AND (p_exclude_withdrawal_id IS NULL OR id != p_exclude_withdrawal_id);
  
  RETURN GREATEST(0, total_earned - total_paid - total_pending);
END;
$function$
"
check_sufficient_funds,"CREATE OR REPLACE FUNCTION public.check_sufficient_funds()
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
generate_daily_earnings,"CREATE OR REPLACE FUNCTION public.generate_daily_earnings()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  inv RECORD;
  today DATE := CURRENT_DATE;
BEGIN
  FOR inv IN 
    SELECT 
      i.id AS investment_id,
      i.user_id,
      i.inversion_actual,
      i.tasa_diaria
    FROM investments i
    WHERE i.inversion_actual > 0
      AND i.tasa_diaria > 0
  LOOP
    INSERT INTO daily_earnings (
      user_id,
      investment_id,
      investment_amount,
      daily_rate,
      earning_amount,
      date
    )
    VALUES (
      inv.user_id,
      inv.investment_id,
      inv.inversion_actual,
      inv.tasa_diaria,
      inv.inversion_actual * (inv.tasa_diaria / 100),
      today
    )
    ON CONFLICT (user_id, date) DO NOTHING;
  END LOOP;
  
  RAISE NOTICE 'Ganancias generadas para %', today;
END;
$function$
"
generate_user_daily_earnings,"CREATE OR REPLACE FUNCTION public.generate_user_daily_earnings(p_user_id uuid)
 RETURNS TABLE(days_generated integer, total_earnings numeric, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_investment RECORD;
  v_last_date DATE;
  v_days_generated INT;
  v_total_earnings NUMERIC;
BEGIN
  -- Obtener inversión
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

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0::NUMERIC, 'No hay inversión activa'::TEXT;
    RETURN;
  END IF;

  v_last_date := v_investment.last_generated;

  -- 🔥 INSERT MASIVO usando investment_history
  WITH date_series AS (
    SELECT generate_series(
      v_last_date + INTERVAL '1 day',
      CURRENT_DATE - INTERVAL '1 day',
      INTERVAL '1 day'
    )::DATE AS earning_date
  ),
  -- Obtener el monto y tasa correctos para cada día
  daily_rates AS (
    SELECT 
      ds.earning_date,
      COALESCE(
        (SELECT amount FROM public.investment_history 
         WHERE investment_id = v_investment.id 
           AND effective_date <= ds.earning_date
         ORDER BY effective_date DESC 
         LIMIT 1),
        v_investment.inversion_actual
      ) as amount,
      COALESCE(
        (SELECT daily_rate FROM public.investment_history 
         WHERE investment_id = v_investment.id 
           AND effective_date <= ds.earning_date
         ORDER BY effective_date DESC 
         LIMIT 1),
        v_investment.tasa_diaria
      ) as rate
    FROM date_series ds
  )
  INSERT INTO public.daily_earnings (
    user_id,
    investment_id,
    investment_amount,
    daily_rate,
    earning_amount,
    date
  )
  SELECT 
    v_investment.user_id,
    v_investment.id,
    dr.amount,
    dr.rate,
    dr.amount * (dr.rate / 100),
    dr.earning_date
  FROM daily_rates dr
  WHERE NOT EXISTS (
    SELECT 1 FROM public.daily_earnings de
    WHERE de.user_id = v_investment.user_id 
      AND de.date = dr.earning_date
  );

  GET DIAGNOSTICS v_days_generated = ROW_COUNT;
  
  v_total_earnings := (
    SELECT SUM(earning_amount) 
    FROM public.daily_earnings 
    WHERE user_id = v_investment.user_id
      AND date > v_last_date
      AND date < CURRENT_DATE
  );

  -- Actualizar última fecha
  IF v_days_generated > 0 THEN
    UPDATE public.investments 
    SET last_week_generated = CURRENT_DATE - INTERVAL '1 day'
    WHERE id = v_investment.id;
  END IF;

  RETURN QUERY SELECT 
    v_days_generated::INTEGER, 
    COALESCE(v_total_earnings, 0)::NUMERIC,
    CASE 
      WHEN v_days_generated > 0 THEN 'Ganancias generadas exitosamente'
      ELSE 'No hay días nuevos para generar'
    END::TEXT;
END;
$function$
"
generate_user_weekly_earnings,"CREATE OR REPLACE FUNCTION public.generate_user_weekly_earnings(p_user_id uuid)
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
get_all_clients_with_investments,"CREATE OR REPLACE FUNCTION public.get_all_clients_with_investments()
 RETURNS TABLE(user_id uuid, full_name text, email text, investment_id uuid, investment_amount numeric, daily_rate numeric, total_earnings numeric, days_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT 
    p.id AS user_id,
    p.full_name,
    p.email,
    i.id AS investment_id,
    COALESCE(i.inversion_actual, 0) AS investment_amount,
    COALESCE(i.tasa_diaria, 0) AS daily_rate,
    COALESCE(SUM(de.earning_amount), 0) AS total_earnings,
    COALESCE(COUNT(DISTINCT de.date), 0)::INTEGER AS days_count
  FROM profiles p
  LEFT JOIN investments i ON i.user_id = p.id
  LEFT JOIN daily_earnings de ON de.user_id = p.id
  WHERE p.role = 'cliente'
  GROUP BY p.id, p.full_name, p.email, i.id, i.inversion_actual, i.tasa_diaria
  ORDER BY p.created_at DESC;
$function$
"
get_client_dashboard_data,"CREATE OR REPLACE FUNCTION public.get_client_dashboard_data(p_user_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT json_build_object(
    'investment', (
      SELECT json_build_object(
        'id', i.id,
        'inversion_actual', i.inversion_actual,
        'tasa_diaria', i.tasa_diaria,
        'created_at', i.created_at
      )
      FROM investments i
      WHERE i.user_id = p_user_id
      LIMIT 1
    ),
    'withdrawals', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id', w.id,
          'monto', w.monto,
          'estado', w.estado,
          'fecha_solicitud', w.fecha_solicitud
        ) ORDER BY w.fecha_solicitud DESC
      ), '[]'::json)
      FROM withdrawals w
      WHERE w.user_id = p_user_id
      LIMIT 20 -- ✅ LIMITAR A 20 RETIROS RECIENTES
    ),
    'total_earnings', (
      SELECT COALESCE(SUM(earning_amount), 0)
      FROM daily_earnings
      WHERE user_id = p_user_id
    ),
    'available_balance', (
      SELECT GREATEST(0, 
        COALESCE(SUM(de.earning_amount), 0) - 
        COALESCE((
          SELECT SUM(monto) 
          FROM withdrawals 
          WHERE user_id = p_user_id 
            AND estado IN ('pagado', 'pendiente')
        ), 0)
      )
      FROM daily_earnings de
      WHERE de.user_id = p_user_id
    )
  );
$function$
"
get_current_week_projection,"CREATE OR REPLACE FUNCTION public.get_current_week_projection(p_user_id uuid)
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
get_system_metrics,"CREATE OR REPLACE FUNCTION public.get_system_metrics()
 RETURNS TABLE(metric text, value text, status text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    'Database Size'::TEXT,
    pg_size_pretty(pg_database_size(current_database()))::TEXT,
    CASE 
      WHEN pg_database_size(current_database()) > 450*1024*1024 
      THEN '⚠️ WARNING' 
      ELSE '✅ OK' 
    END::TEXT
  UNION ALL
  SELECT 
    'Active Connections',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) > 10 
      THEN '⚠️ HIGH' 
      ELSE '✅ OK' 
    END
  FROM pg_stat_activity
  WHERE datname = current_database()
  UNION ALL
  SELECT 
    'Pending Withdrawals',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) > 20 
      THEN '⚠️ REVIEW' 
      ELSE '✅ OK' 
    END
  FROM withdrawals
  WHERE estado = 'pendiente'
  UNION ALL
  SELECT 
    'Daily Earnings Today',
    COUNT(*)::TEXT,
    CASE 
      WHEN COUNT(*) = 0 
      THEN '❌ ERROR' 
      ELSE '✅ OK' 
    END
  FROM daily_earnings
  WHERE date = CURRENT_DATE;
END;
$function$
"
get_user_role,"CREATE OR REPLACE FUNCTION public.get_user_role()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$function$
"
get_user_total_earnings,"CREATE OR REPLACE FUNCTION public.get_user_total_earnings(p_user_id uuid)
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
get_withdrawals_with_balances,"CREATE OR REPLACE FUNCTION public.get_withdrawals_with_balances()
 RETURNS TABLE(withdrawal_id uuid, user_id uuid, user_name text, user_email text, monto numeric, estado text, fecha_solicitud timestamp with time zone, available_balance numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    w.id AS withdrawal_id,
    w.user_id,
    p.full_name AS user_name,
    p.email AS user_email,
    w.monto,
    w.estado,
    w.fecha_solicitud,
    GREATEST(0, 
      COALESCE(SUM(de.earning_amount), 0) - 
      COALESCE((
        SELECT SUM(monto) 
        FROM withdrawals 
        WHERE user_id = w.user_id 
          AND estado IN ('pagado', 'pendiente')
          AND id != w.id -- Excluir el retiro actual
      ), 0)
    ) AS available_balance
  FROM withdrawals w
  INNER JOIN profiles p ON p.id = w.user_id
  LEFT JOIN daily_earnings de ON de.user_id = w.user_id
  GROUP BY w.id, w.user_id, p.full_name, p.email, w.monto, w.estado, w.fecha_solicitud
  ORDER BY w.fecha_solicitud DESC;
END;
$function$
"
handle_new_user,"CREATE OR REPLACE FUNCTION public.handle_new_user()
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
initialize_investment,"CREATE OR REPLACE FUNCTION public.initialize_investment()
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
is_admin,"CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT EXISTS (
    SELECT 1 
    FROM profiles 
    WHERE id = auth.uid() 
      AND role = 'admin'
  );
$function$
"
log_investment_change,"CREATE OR REPLACE FUNCTION public.log_investment_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Solo registrar si cambia el monto o la tasa
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       NEW.inversion_actual != OLD.inversion_actual OR 
       NEW.tasa_diaria != OLD.tasa_diaria
     )) THEN
    
    -- Insertar snapshot del cambio
    INSERT INTO public.investment_history (
      user_id,
      investment_id,
      amount,
      daily_rate,
      effective_date
    ) VALUES (
      NEW.user_id,
      NEW.id,
      NEW.inversion_actual,
      NEW.tasa_diaria,
      CURRENT_DATE
    )
    ON CONFLICT (investment_id, effective_date) 
    DO UPDATE SET 
      amount = EXCLUDED.amount,
      daily_rate = EXCLUDED.daily_rate;
  END IF;
  
  RETURN NEW;
END;
$function$
"