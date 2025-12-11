// tablas y columnas 

table_name,column_name,data_type,is_nullable,column_default
daily_earnings,id,uuid,NO,gen_random_uuid()
daily_earnings,user_id,uuid,NO,null
daily_earnings,investment_id,uuid,NO,null
daily_earnings,investment_amount,numeric,NO,null
daily_earnings,daily_rate,numeric,NO,null
daily_earnings,earning_amount,numeric,NO,null
daily_earnings,date,date,NO,null
daily_earnings,created_at,timestamp with time zone,NO,now()
daily_earnings_log,id,uuid,NO,gen_random_uuid()
daily_earnings_log,generation_date,date,NO,null
daily_earnings_log,generated_by,uuid,YES,null
daily_earnings_log,created_at,timestamp with time zone,YES,now()
investment_history,id,uuid,NO,gen_random_uuid()
investment_history,user_id,uuid,NO,null
investment_history,investment_id,uuid,NO,null
investment_history,amount,numeric,NO,null
investment_history,daily_rate,numeric,NO,null
investment_history,effective_date,date,NO,CURRENT_DATE
investment_history,created_at,timestamp with time zone,NO,now()
investments,id,uuid,NO,gen_random_uuid()
investments,user_id,uuid,NO,null
investments,inversion_actual,numeric,NO,0
investments,tasa_diaria,numeric,NO,0
investments,ganancia_acumulada,numeric,NO,0
investments,last_week_generated,date,YES,null
investments,created_at,timestamp with time zone,NO,now()
investments,updated_at,timestamp with time zone,NO,now()
investments,pendiente,numeric,YES,0
profiles,id,uuid,NO,null
profiles,email,text,NO,null
profiles,full_name,text,NO,null
profiles,role,text,YES,'cliente'::text
profiles,created_at,timestamp with time zone,NO,now()
profiles,updated_at,timestamp with time zone,NO,now()
withdrawals,id,uuid,NO,gen_random_uuid()
withdrawals,user_id,uuid,NO,null
withdrawals,monto,numeric,NO,null
withdrawals,estado,text,NO,'pendiente'::text
withdrawals,fecha_solicitud,timestamp with time zone,NO,now()
withdrawals,fecha_procesado,timestamp with time zone,YES,null
withdrawals,created_at,timestamp with time zone,NO,now()
withdrawals,comentario_rechazo,text,YES,null

// triggers
table_name,trigger_name,event,action_timing,action_statement
investments,investment_history_trigger,INSERT,AFTER,EXECUTE FUNCTION log_investment_change()
investments,investment_history_trigger,UPDATE,AFTER,EXECUTE FUNCTION log_investment_change()
investments,on_investment_created,INSERT,BEFORE,EXECUTE FUNCTION initialize_investment()

// triggers mas funciones asociadas
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

// indice
table_name,index_name,index_definition,is_unique,is_primary
daily_earnings,daily_earnings_pkey,CREATE UNIQUE INDEX daily_earnings_pkey ON public.daily_earnings USING btree (id),true,true
daily_earnings,daily_earnings_user_id_date_key,"CREATE UNIQUE INDEX daily_earnings_user_id_date_key ON public.daily_earnings USING btree (user_id, date)",true,false
daily_earnings,idx_daily_earnings_date,"CREATE INDEX idx_daily_earnings_date ON public.daily_earnings USING btree (date DESC) INCLUDE (user_id, earning_amount)",false,false
daily_earnings,idx_daily_earnings_user_sum,CREATE INDEX idx_daily_earnings_user_sum ON public.daily_earnings USING btree (user_id) INCLUDE (earning_amount) WHERE (earning_amount > (0)::numeric),false,false
daily_earnings_log,daily_earnings_log_generation_date_key,CREATE UNIQUE INDEX daily_earnings_log_generation_date_key ON public.daily_earnings_log USING btree (generation_date),true,false
daily_earnings_log,daily_earnings_log_pkey,CREATE UNIQUE INDEX daily_earnings_log_pkey ON public.daily_earnings_log USING btree (id),true,true
daily_earnings_log,idx_daily_earnings_log_date,CREATE INDEX idx_daily_earnings_log_date ON public.daily_earnings_log USING btree (generation_date DESC),false,false
investment_history,idx_investment_history_lookup,"CREATE INDEX idx_investment_history_lookup ON public.investment_history USING btree (investment_id, effective_date DESC) INCLUDE (amount, daily_rate)",false,false
investment_history,investment_history_investment_id_effective_date_key,"CREATE UNIQUE INDEX investment_history_investment_id_effective_date_key ON public.investment_history USING btree (investment_id, effective_date)",true,false
investment_history,investment_history_pkey,CREATE UNIQUE INDEX investment_history_pkey ON public.investment_history USING btree (id),true,true
investments,idx_investments_created,CREATE INDEX idx_investments_created ON public.investments USING btree (created_at DESC),false,false
investments,idx_investments_pendiente,"CREATE INDEX idx_investments_pendiente ON public.investments USING btree (user_id, pendiente) WHERE (pendiente > (0)::numeric)",false,false
investments,idx_investments_user_active,"CREATE INDEX idx_investments_user_active ON public.investments USING btree (user_id, inversion_actual) INCLUDE (id, tasa_diaria) WHERE (inversion_actual > (0)::numeric)",false,false
investments,investments_pkey,CREATE UNIQUE INDEX investments_pkey ON public.investments USING btree (id),true,true
investments,investments_user_id_key,CREATE UNIQUE INDEX investments_user_id_key ON public.investments USING btree (user_id),true,false
profiles,idx_profiles_auth_admin,"CREATE INDEX idx_profiles_auth_admin ON public.profiles USING btree (id, role) WHERE (role = 'admin'::text)",false,false
profiles,idx_profiles_role_created,"CREATE INDEX idx_profiles_role_created ON public.profiles USING btree (role, created_at DESC) INCLUDE (id, full_name, email) WHERE (role = 'cliente'::text)",false,false
profiles,profiles_email_key,CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email),true,false
profiles,profiles_pkey,CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id),true,true
withdrawals,idx_withdrawals_estado_fecha,"CREATE INDEX idx_withdrawals_estado_fecha ON public.withdrawals USING btree (estado, fecha_solicitud DESC) INCLUDE (user_id, monto)",false,false
withdrawals,idx_withdrawals_pending,"CREATE INDEX idx_withdrawals_pending ON public.withdrawals USING btree (user_id, monto, fecha_solicitud DESC) WHERE (estado = 'pendiente'::text)",false,false
withdrawals,idx_withdrawals_rechazado_comment,"CREATE INDEX idx_withdrawals_rechazado_comment ON public.withdrawals USING btree (estado, comentario_rechazo) WHERE (estado = 'rechazado'::text)",false,false
withdrawals,idx_withdrawals_user_estado,"CREATE INDEX idx_withdrawals_user_estado ON public.withdrawals USING btree (user_id, estado, fecha_solicitud DESC) INCLUDE (monto)",false,false
withdrawals,withdrawals_pkey,CREATE UNIQUE INDEX withdrawals_pkey ON public.withdrawals USING btree (id),true,true


// policies

schemaname,tablename,policyname,permissive,roles,command,using_expression,check_expression
public,daily_earnings,admin_or_own_select_earnings,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,daily_earnings,system_insert_earnings,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)
public,daily_earnings_log,Solo admins pueden registrar generación,PERMISSIVE,{public},INSERT,null,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))"
public,daily_earnings_log,Solo admins pueden ver el log de ganancias,PERMISSIVE,{public},SELECT,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))",null
public,investment_history,admin_insert_history,PERMISSIVE,{public},INSERT,null,is_admin()
public,investment_history,admin_or_own_select_history,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,investments,admin_manage_investments,PERMISSIVE,{public},ALL,is_admin(),null
public,investments,admin_or_own_select_investments,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,profiles,admin_insert_profiles,PERMISSIVE,{public},INSERT,null,(is_admin() OR (auth.uid() = id))
public,profiles,admin_or_own_select_profiles,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = id)),null
public,profiles,admin_or_own_update_profiles,PERMISSIVE,{public},UPDATE,(is_admin() OR (auth.uid() = id)),null
public,withdrawals,admin_or_own_select_withdrawals,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,withdrawals,admin_update_withdrawals,PERMISSIVE,{public},UPDATE,is_admin(),null
public,withdrawals,user_insert_withdrawals,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)


// funciones 

function_name,schema,definition
generate_daily_earnings_manual,public,"CREATE OR REPLACE FUNCTION public.generate_daily_earnings_manual()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_already_generated BOOLEAN;
  v_affected_users INT := 0;
  v_total_generated NUMERIC := 0;
  v_result JSON;
BEGIN
  -- 1. ✅ VERIFICAR SI YA SE GENERÓ HOY
  SELECT EXISTS (
    SELECT 1 FROM public.daily_earnings_log 
    WHERE generation_date = v_today
  ) INTO v_already_generated;

  IF v_already_generated THEN
    RETURN json_build_object(
      'success', false,
      'message', '❌ Las ganancias de hoy ya fueron generadas',
      'date', v_today,
      'users_affected', 0,
      'total_generated', 0
    );
  END IF;

  -- 2. ✅ GENERAR GANANCIAS (solo para inversiones activas)
  WITH earnings AS (
    SELECT 
      i.user_id,
      i.id AS investment_id,
      i.inversion_actual,
      i.tasa_diaria,
      (i.inversion_actual * (i.tasa_diaria / 100)) AS daily_earning
    FROM public.investments i
    WHERE i.inversion_actual > 0 
      AND i.tasa_diaria > 0
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
    user_id,
    investment_id,
    inversion_actual,
    tasa_diaria,
    daily_earning,
    v_today
  FROM earnings
  RETURNING user_id INTO v_affected_users;

  -- 3. ✅ CONTAR USUARIOS AFECTADOS Y TOTAL GENERADO
  GET DIAGNOSTICS v_affected_users = ROW_COUNT;

  SELECT COALESCE(SUM(earning_amount), 0)
  INTO v_total_generated
  FROM public.daily_earnings
  WHERE date = v_today;

  -- 4. ✅ REGISTRAR LA GENERACIÓN EN EL LOG
  INSERT INTO public.daily_earnings_log (generation_date, generated_by)
  VALUES (v_today, auth.uid());

  -- 5. ✅ RETORNAR RESULTADO
  RETURN json_build_object(
    'success', true,
    'message', '✅ Ganancias generadas exitosamente',
    'date', v_today,
    'users_affected', v_affected_users,
    'total_generated', v_total_generated
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', '❌ Error: ' || SQLERRM,
      'date', v_today,
      'users_affected', 0,
      'total_generated', 0
    );
END;
$function$
"
get_all_clients_with_investments,public,"CREATE OR REPLACE FUNCTION public.get_all_clients_with_investments()
 RETURNS TABLE(user_id uuid, full_name text, email text, investment_id uuid, investment_amount numeric, daily_rate numeric, pendiente numeric, total_earnings numeric, days_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id AS user_id,
    p.full_name,
    p.email,
    i.id AS investment_id,
    COALESCE(i.inversion_actual, 0) AS investment_amount,
    COALESCE(i.tasa_diaria, 0) AS daily_rate,
    COALESCE(i.pendiente, 0) AS pendiente,  -- ✅ NUEVO
    COALESCE(
      CASE 
        WHEN i.inversion_actual > 0 AND i.tasa_diaria > 0 THEN
          i.inversion_actual * (i.tasa_diaria / 100) * 
          GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE)))
        ELSE 0
      END, 0
    )::NUMERIC AS total_earnings,
    COALESCE(
      CASE 
        WHEN i.created_at IS NOT NULL THEN
          GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE)))::INTEGER
        ELSE 0
      END, 0
    ) AS days_count
  FROM profiles p
  LEFT JOIN investments i ON i.user_id = p.id
  WHERE p.role = 'cliente'
  ORDER BY p.created_at DESC;
END;
$function$
"
get_client_dashboard_data,public,"CREATE OR REPLACE FUNCTION public.get_client_dashboard_data(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_investment record;
  v_withdrawals jsonb;
  v_total_earned numeric;
  v_total_withdrawn numeric;
  v_pending_withdrawn numeric;
  v_available_balance numeric;
BEGIN
  -- Obtener inversión activa
  SELECT 
    id,
    user_id,
    inversion_actual,
    tasa_diaria,
    created_at
  INTO v_investment
  FROM investments
  WHERE user_id = p_user_id
  LIMIT 1;

  -- Si no tiene inversión, retornar null
  IF v_investment.id IS NULL THEN
    RETURN jsonb_build_object(
      'investment', NULL,
      'withdrawals', '[]'::jsonb,
      'available_balance', 0,
      'total_earnings', 0
    );
  END IF;

  -- Calcular ganancias totales
  v_total_earned := CASE 
    WHEN v_investment.inversion_actual > 0 AND v_investment.tasa_diaria > 0 THEN
      (v_investment.inversion_actual * (v_investment.tasa_diaria / 100) * 
       GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, v_investment.created_at::DATE))))::numeric
    ELSE 
      0::numeric
  END;

  -- Obtener retiros con comentarios
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', w.id,
      'monto', w.monto,
      'estado', w.estado,
      'fecha_solicitud', w.fecha_solicitud,
      'comentario_rechazo', w.comentario_rechazo
    ) ORDER BY w.fecha_solicitud DESC
  )
  INTO v_withdrawals
  FROM withdrawals w
  WHERE w.user_id = p_user_id;

  -- Calcular totales de retiros
  SELECT 
    COALESCE(SUM(CASE WHEN estado = 'pagado' THEN monto ELSE 0 END), 0)::numeric,
    COALESCE(SUM(CASE WHEN estado = 'pendiente' THEN monto ELSE 0 END), 0)::numeric
  INTO v_total_withdrawn, v_pending_withdrawn
  FROM withdrawals
  WHERE user_id = p_user_id;

  -- Calcular balance disponible
  v_available_balance := GREATEST(0, v_total_earned - v_total_withdrawn - v_pending_withdrawn)::numeric;

  -- Retornar todo en un objeto JSON
  RETURN jsonb_build_object(
    'investment', jsonb_build_object(
      'id', v_investment.id,
      'user_id', v_investment.user_id,
      'inversion_actual', v_investment.inversion_actual,
      'tasa_diaria', v_investment.tasa_diaria,
      'created_at', v_investment.created_at
    ),
    'withdrawals', COALESCE(v_withdrawals, '[]'::jsonb),
    'available_balance', v_available_balance,
    'total_earnings', v_total_earned
  );
END;
$function$
"
get_withdrawals_with_balances,public,"CREATE OR REPLACE FUNCTION public.get_withdrawals_with_balances()
 RETURNS TABLE(withdrawal_id uuid, user_id uuid, user_name text, user_email text, monto numeric, estado text, fecha_solicitud timestamp with time zone, comentario_rechazo text, available_balance numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH user_earnings AS (
        SELECT 
            i.user_id AS uid,
            CASE 
                WHEN i.inversion_actual > 0 AND i.tasa_diaria > 0 THEN
                    (i.inversion_actual * (i.tasa_diaria / 100) * 
                    GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE))))::numeric
                ELSE 
                    0::numeric
            END AS total_earned
        FROM investments i
    ),
    user_withdrawals AS (
        SELECT 
            wd.user_id AS uid,
            COALESCE(SUM(wd.monto), 0)::numeric AS total_withdrawn
        FROM withdrawals wd
        WHERE wd.estado IN ('pagado', 'pendiente')
        GROUP BY wd.user_id
    )
    SELECT 
        w.id AS withdrawal_id,
        w.user_id,
        p.full_name AS user_name,
        p.email AS user_email,
        w.monto,
        w.estado,
        w.fecha_solicitud,
        w.comentario_rechazo,
        GREATEST(
            0::numeric, 
            (COALESCE(ue.total_earned, 0) - 
             COALESCE(uw.total_withdrawn, 0) + 
             CASE 
                WHEN w.estado = 'pendiente' THEN w.monto 
                ELSE 0 
             END)::numeric
        ) AS available_balance
    FROM withdrawals w
    INNER JOIN profiles p ON p.id = w.user_id
    LEFT JOIN user_earnings ue ON ue.uid = w.user_id
    LEFT JOIN user_withdrawals uw ON uw.uid = w.user_id
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
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario Nuevo'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'cliente')
  );
  RETURN NEW;
END;
$function$
"
initialize_investment,public,"CREATE OR REPLACE FUNCTION public.initialize_investment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.last_week_generated := (CURRENT_DATE - INTERVAL '1 day')::DATE;
  RETURN NEW;
END;
$function$
"
is_admin,public,"CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$
"
log_investment_change,public,"CREATE OR REPLACE FUNCTION public.log_investment_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       NEW.inversion_actual != OLD.inversion_actual OR 
       NEW.tasa_diaria != OLD.tasa_diaria
     )) THEN
    
    INSERT INTO investment_history (
      user_id, investment_id, amount, daily_rate, effective_date
    ) VALUES (
      NEW.user_id, NEW.id, NEW.inversion_actual, NEW.tasa_diaria, CURRENT_DATE
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


/// funciones rpc expuestas via api

rpc_name,definition
generate_daily_earnings_manual,"CREATE OR REPLACE FUNCTION public.generate_daily_earnings_manual()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_already_generated BOOLEAN;
  v_affected_users INT := 0;
  v_total_generated NUMERIC := 0;
  v_result JSON;
BEGIN
  -- 1. ✅ VERIFICAR SI YA SE GENERÓ HOY
  SELECT EXISTS (
    SELECT 1 FROM public.daily_earnings_log 
    WHERE generation_date = v_today
  ) INTO v_already_generated;

  IF v_already_generated THEN
    RETURN json_build_object(
      'success', false,
      'message', '❌ Las ganancias de hoy ya fueron generadas',
      'date', v_today,
      'users_affected', 0,
      'total_generated', 0
    );
  END IF;

  -- 2. ✅ GENERAR GANANCIAS (solo para inversiones activas)
  WITH earnings AS (
    SELECT 
      i.user_id,
      i.id AS investment_id,
      i.inversion_actual,
      i.tasa_diaria,
      (i.inversion_actual * (i.tasa_diaria / 100)) AS daily_earning
    FROM public.investments i
    WHERE i.inversion_actual > 0 
      AND i.tasa_diaria > 0
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
    user_id,
    investment_id,
    inversion_actual,
    tasa_diaria,
    daily_earning,
    v_today
  FROM earnings
  RETURNING user_id INTO v_affected_users;

  -- 3. ✅ CONTAR USUARIOS AFECTADOS Y TOTAL GENERADO
  GET DIAGNOSTICS v_affected_users = ROW_COUNT;

  SELECT COALESCE(SUM(earning_amount), 0)
  INTO v_total_generated
  FROM public.daily_earnings
  WHERE date = v_today;

  -- 4. ✅ REGISTRAR LA GENERACIÓN EN EL LOG
  INSERT INTO public.daily_earnings_log (generation_date, generated_by)
  VALUES (v_today, auth.uid());

  -- 5. ✅ RETORNAR RESULTADO
  RETURN json_build_object(
    'success', true,
    'message', '✅ Ganancias generadas exitosamente',
    'date', v_today,
    'users_affected', v_affected_users,
    'total_generated', v_total_generated
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', '❌ Error: ' || SQLERRM,
      'date', v_today,
      'users_affected', 0,
      'total_generated', 0
    );
END;
$function$
"
get_all_clients_with_investments,"CREATE OR REPLACE FUNCTION public.get_all_clients_with_investments()
 RETURNS TABLE(user_id uuid, full_name text, email text, investment_id uuid, investment_amount numeric, daily_rate numeric, pendiente numeric, total_earnings numeric, days_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id AS user_id,
    p.full_name,
    p.email,
    i.id AS investment_id,
    COALESCE(i.inversion_actual, 0) AS investment_amount,
    COALESCE(i.tasa_diaria, 0) AS daily_rate,
    COALESCE(i.pendiente, 0) AS pendiente,  -- ✅ NUEVO
    COALESCE(
      CASE 
        WHEN i.inversion_actual > 0 AND i.tasa_diaria > 0 THEN
          i.inversion_actual * (i.tasa_diaria / 100) * 
          GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE)))
        ELSE 0
      END, 0
    )::NUMERIC AS total_earnings,
    COALESCE(
      CASE 
        WHEN i.created_at IS NOT NULL THEN
          GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE)))::INTEGER
        ELSE 0
      END, 0
    ) AS days_count
  FROM profiles p
  LEFT JOIN investments i ON i.user_id = p.id
  WHERE p.role = 'cliente'
  ORDER BY p.created_at DESC;
END;
$function$
"
get_client_dashboard_data,"CREATE OR REPLACE FUNCTION public.get_client_dashboard_data(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_investment record;
  v_withdrawals jsonb;
  v_total_earned numeric;
  v_total_withdrawn numeric;
  v_pending_withdrawn numeric;
  v_available_balance numeric;
BEGIN
  -- Obtener inversión activa
  SELECT 
    id,
    user_id,
    inversion_actual,
    tasa_diaria,
    created_at
  INTO v_investment
  FROM investments
  WHERE user_id = p_user_id
  LIMIT 1;

  -- Si no tiene inversión, retornar null
  IF v_investment.id IS NULL THEN
    RETURN jsonb_build_object(
      'investment', NULL,
      'withdrawals', '[]'::jsonb,
      'available_balance', 0,
      'total_earnings', 0
    );
  END IF;

  -- Calcular ganancias totales
  v_total_earned := CASE 
    WHEN v_investment.inversion_actual > 0 AND v_investment.tasa_diaria > 0 THEN
      (v_investment.inversion_actual * (v_investment.tasa_diaria / 100) * 
       GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, v_investment.created_at::DATE))))::numeric
    ELSE 
      0::numeric
  END;

  -- Obtener retiros con comentarios
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', w.id,
      'monto', w.monto,
      'estado', w.estado,
      'fecha_solicitud', w.fecha_solicitud,
      'comentario_rechazo', w.comentario_rechazo
    ) ORDER BY w.fecha_solicitud DESC
  )
  INTO v_withdrawals
  FROM withdrawals w
  WHERE w.user_id = p_user_id;

  -- Calcular totales de retiros
  SELECT 
    COALESCE(SUM(CASE WHEN estado = 'pagado' THEN monto ELSE 0 END), 0)::numeric,
    COALESCE(SUM(CASE WHEN estado = 'pendiente' THEN monto ELSE 0 END), 0)::numeric
  INTO v_total_withdrawn, v_pending_withdrawn
  FROM withdrawals
  WHERE user_id = p_user_id;

  -- Calcular balance disponible
  v_available_balance := GREATEST(0, v_total_earned - v_total_withdrawn - v_pending_withdrawn)::numeric;

  -- Retornar todo en un objeto JSON
  RETURN jsonb_build_object(
    'investment', jsonb_build_object(
      'id', v_investment.id,
      'user_id', v_investment.user_id,
      'inversion_actual', v_investment.inversion_actual,
      'tasa_diaria', v_investment.tasa_diaria,
      'created_at', v_investment.created_at
    ),
    'withdrawals', COALESCE(v_withdrawals, '[]'::jsonb),
    'available_balance', v_available_balance,
    'total_earnings', v_total_earned
  );
END;
$function$
"
get_withdrawals_with_balances,"CREATE OR REPLACE FUNCTION public.get_withdrawals_with_balances()
 RETURNS TABLE(withdrawal_id uuid, user_id uuid, user_name text, user_email text, monto numeric, estado text, fecha_solicitud timestamp with time zone, comentario_rechazo text, available_balance numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH user_earnings AS (
        SELECT 
            i.user_id AS uid,
            CASE 
                WHEN i.inversion_actual > 0 AND i.tasa_diaria > 0 THEN
                    (i.inversion_actual * (i.tasa_diaria / 100) * 
                    GREATEST(0, DATE_PART('day', AGE(CURRENT_DATE, i.created_at::DATE))))::numeric
                ELSE 
                    0::numeric
            END AS total_earned
        FROM investments i
    ),
    user_withdrawals AS (
        SELECT 
            wd.user_id AS uid,
            COALESCE(SUM(wd.monto), 0)::numeric AS total_withdrawn
        FROM withdrawals wd
        WHERE wd.estado IN ('pagado', 'pendiente')
        GROUP BY wd.user_id
    )
    SELECT 
        w.id AS withdrawal_id,
        w.user_id,
        p.full_name AS user_name,
        p.email AS user_email,
        w.monto,
        w.estado,
        w.fecha_solicitud,
        w.comentario_rechazo,
        GREATEST(
            0::numeric, 
            (COALESCE(ue.total_earned, 0) - 
             COALESCE(uw.total_withdrawn, 0) + 
             CASE 
                WHEN w.estado = 'pendiente' THEN w.monto 
                ELSE 0 
             END)::numeric
        ) AS available_balance
    FROM withdrawals w
    INNER JOIN profiles p ON p.id = w.user_id
    LEFT JOIN user_earnings ue ON ue.uid = w.user_id
    LEFT JOIN user_withdrawals uw ON uw.uid = w.user_id
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
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario Nuevo'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'cliente')
  );
  RETURN NEW;
END;
$function$
"
initialize_investment,"CREATE OR REPLACE FUNCTION public.initialize_investment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.last_week_generated := (CURRENT_DATE - INTERVAL '1 day')::DATE;
  RETURN NEW;
END;
$function$
"
is_admin,"CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$
"
log_investment_change,"CREATE OR REPLACE FUNCTION public.log_investment_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       NEW.inversion_actual != OLD.inversion_actual OR 
       NEW.tasa_diaria != OLD.tasa_diaria
     )) THEN
    
    INSERT INTO investment_history (
      user_id, investment_id, amount, daily_rate, effective_date
    ) VALUES (
      NEW.user_id, NEW.id, NEW.inversion_actual, NEW.tasa_diaria, CURRENT_DATE
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