//tablas y columnas

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


//policies 

schemaname,tablename,policyname,permissive,roles,command,using_expression,with_check
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

// supabase indices
table_name,index_name,index_definition
daily_earnings,daily_earnings_pkey,CREATE UNIQUE INDEX daily_earnings_pkey ON public.daily_earnings USING btree (id)
daily_earnings,idx_daily_earnings_date,CREATE INDEX idx_daily_earnings_date ON public.daily_earnings USING btree (date DESC)
daily_earnings,idx_daily_earnings_lookup,"CREATE INDEX idx_daily_earnings_lookup ON public.daily_earnings USING btree (user_id, date DESC) INCLUDE (earning_amount)"
daily_earnings,idx_daily_earnings_user,CREATE INDEX idx_daily_earnings_user ON public.daily_earnings USING btree (user_id)
daily_earnings,idx_daily_earnings_user_date,"CREATE INDEX idx_daily_earnings_user_date ON public.daily_earnings USING btree (user_id, date DESC)"
daily_earnings,unique_user_day,"CREATE UNIQUE INDEX unique_user_day ON public.daily_earnings USING btree (user_id, date)"
investment_history,idx_investment_history_date,CREATE INDEX idx_investment_history_date ON public.investment_history USING btree (effective_date DESC)
investment_history,idx_investment_history_investment,CREATE INDEX idx_investment_history_investment ON public.investment_history USING btree (investment_id)
investment_history,idx_investment_history_user,CREATE INDEX idx_investment_history_user ON public.investment_history USING btree (user_id)
investment_history,investment_history_pkey,CREATE UNIQUE INDEX investment_history_pkey ON public.investment_history USING btree (id)
investment_history,unique_investment_date,"CREATE UNIQUE INDEX unique_investment_date ON public.investment_history USING btree (investment_id, effective_date)"
investments,idx_investments_created_at,CREATE INDEX idx_investments_created_at ON public.investments USING btree (created_at DESC)
investments,idx_investments_user_created,"CREATE INDEX idx_investments_user_created ON public.investments USING btree (user_id, created_at DESC)"
investments,investments_pkey,CREATE UNIQUE INDEX investments_pkey ON public.investments USING btree (id)
profiles,idx_profiles_cliente_active,"CREATE INDEX idx_profiles_cliente_active ON public.profiles USING btree (id, email, created_at DESC) WHERE (role = 'cliente'::text)"
profiles,idx_profiles_created_at,CREATE INDEX idx_profiles_created_at ON public.profiles USING btree (created_at DESC)
profiles,idx_profiles_role,CREATE INDEX idx_profiles_role ON public.profiles USING btree (role)
profiles,profiles_email_key,CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email)
profiles,profiles_pkey,CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)
withdrawals,idx_withdrawals_estado,CREATE INDEX idx_withdrawals_estado ON public.withdrawals USING btree (estado)
withdrawals,idx_withdrawals_estado_fecha,"CREATE INDEX idx_withdrawals_estado_fecha ON public.withdrawals USING btree (estado, fecha_solicitud DESC)"
withdrawals,idx_withdrawals_fecha_solicitud,CREATE INDEX idx_withdrawals_fecha_solicitud ON public.withdrawals USING btree (fecha_solicitud DESC)
withdrawals,idx_withdrawals_pending_only,"CREATE INDEX idx_withdrawals_pending_only ON public.withdrawals USING btree (user_id, monto, fecha_solicitud DESC) WHERE (estado = 'pendiente'::text)"
withdrawals,idx_withdrawals_user_estado,"CREATE INDEX idx_withdrawals_user_estado ON public.withdrawals USING btree (user_id, estado)"
withdrawals,idx_withdrawals_user_estado_monto,"CREATE INDEX idx_withdrawals_user_estado_monto ON public.withdrawals USING btree (user_id, estado, monto)"
withdrawals,idx_withdrawals_user_id,CREATE INDEX idx_withdrawals_user_id ON public.withdrawals USING btree (user_id)
withdrawals,idx_withdrawals_user_pending,CREATE INDEX idx_withdrawals_user_pending ON public.withdrawals USING btree (user_id) WHERE (estado = 'pendiente'::text)
withdrawals,withdrawals_pkey,CREATE UNIQUE INDEX withdrawals_pkey ON public.withdrawals USING btree (id)


//triggers
trigger_name,table_name,trigger_definition
investment_history_trigger,investments,CREATE TRIGGER investment_history_trigger AFTER INSERT OR UPDATE ON public.investments FOR EACH ROW EXECUTE FUNCTION log_investment_change()
on_investment_created,investments,CREATE TRIGGER on_investment_created BEFORE INSERT ON public.investments FOR EACH ROW EXECUTE FUNCTION initialize_investment()

// foreing keys y constraints
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
daily_earnings,unique_user_day,UNIQUE,date,daily_earnings,date
daily_earnings,unique_user_day,UNIQUE,user_id,daily_earnings,date
daily_earnings,unique_user_day,UNIQUE,user_id,daily_earnings,user_id
daily_earnings,unique_user_day,UNIQUE,date,daily_earnings,user_id
investment_history,2200_36050_5_not_null,CHECK,null,null,null
investment_history,2200_36050_6_not_null,CHECK,null,null,null
investment_history,2200_36050_1_not_null,CHECK,null,null,null
investment_history,2200_36050_2_not_null,CHECK,null,null,null
investment_history,2200_36050_3_not_null,CHECK,null,null,null
investment_history,2200_36050_4_not_null,CHECK,null,null,null
investment_history,investment_history_user_id_fkey,FOREIGN KEY,user_id,profiles,id
investment_history,investment_history_investment_id_fkey,FOREIGN KEY,investment_id,investments,id
investment_history,investment_history_pkey,PRIMARY KEY,id,investment_history,id
investment_history,unique_investment_date,UNIQUE,investment_id,investment_history,investment_id
investment_history,unique_investment_date,UNIQUE,effective_date,investment_history,effective_date
investment_history,unique_investment_date,UNIQUE,effective_date,investment_history,investment_id
investment_history,unique_investment_date,UNIQUE,investment_id,investment_history,effective_date
investments,2200_17505_2_not_null,CHECK,null,null,null
investments,2200_17505_1_not_null,CHECK,null,null,null
investments,investments_user_id_fkey,FOREIGN KEY,user_id,profiles,id
investments,investments_pkey,PRIMARY KEY,id,investments,id
profiles,profiles_role_check,CHECK,null,profiles,role
profiles,2200_17487_2_not_null,CHECK,null,null,null
profiles,2200_17487_1_not_null,CHECK,null,null,null
profiles,profiles_id_fkey,FOREIGN KEY,id,null,null
profiles,profiles_pkey,PRIMARY KEY,id,profiles,id
profiles,profiles_email_key,UNIQUE,email,profiles,email
withdrawals,2200_17523_3_not_null,CHECK,null,null,null
withdrawals,2200_17523_2_not_null,CHECK,null,null,null
withdrawals,2200_17523_1_not_null,CHECK,null,null,null
withdrawals,withdrawals_estado_check,CHECK,null,withdrawals,estado
withdrawals,withdrawals_user_id_fkey,FOREIGN KEY,user_id,profiles,id
withdrawals,withdrawals_pkey,PRIMARY KEY,id,withdrawals,id