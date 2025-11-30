-- --------------------------------------------------------
.. supabase


// politicas 

schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
public,investments,admin_delete_investments,PERMISSIVE,{public},DELETE,is_admin(),null
public,investments,admin_insert_investments,PERMISSIVE,{public},INSERT,null,is_admin()
public,investments,admin_or_own_select_investments,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,investments,admin_update_investments,PERMISSIVE,{public},UPDATE,is_admin(),is_admin()
public,profiles,admin_delete_profiles,PERMISSIVE,{public},DELETE,is_admin(),null
public,profiles,admin_insert_profiles,PERMISSIVE,{public},INSERT,null,(is_admin() OR (auth.uid() = id))
public,profiles,admin_or_own_select_profiles,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = id)),null
public,profiles,admin_or_own_update_profiles,PERMISSIVE,{public},UPDATE,(is_admin() OR (auth.uid() = id)),(is_admin() OR (auth.uid() = id))
public,weekly_earnings,Admins ven todas las ganancias,PERMISSIVE,{public},SELECT,"(EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))",null
public,weekly_earnings,Sistema inserta ganancias,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)
public,weekly_earnings,Usuarios ven sus ganancias,PERMISSIVE,{public},SELECT,(auth.uid() = user_id),null
public,withdrawals,admin_delete_withdrawals,PERMISSIVE,{public},DELETE,is_admin(),null
public,withdrawals,admin_or_own_select_withdrawals,PERMISSIVE,{public},SELECT,(is_admin() OR (auth.uid() = user_id)),null
public,withdrawals,admin_update_withdrawals,PERMISSIVE,{public},UPDATE,is_admin(),is_admin()
public,withdrawals,user_insert_withdrawals,PERMISSIVE,{public},INSERT,null,(auth.uid() = user_id)


// funciones 
function_name,definition
_crypto_aead_det_decrypt,"CREATE OR REPLACE FUNCTION vault._crypto_aead_det_decrypt(message bytea, additional bytea, key_id bigint, context bytea DEFAULT '\x7067736f6469756d'::bytea, nonce bytea DEFAULT NULL::bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_decrypt_by_id$function$
"
_crypto_aead_det_encrypt,"CREATE OR REPLACE FUNCTION vault._crypto_aead_det_encrypt(message bytea, additional bytea, key_id bigint, context bytea DEFAULT '\x7067736f6469756d'::bytea, nonce bytea DEFAULT NULL::bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_encrypt_by_id$function$
"
_crypto_aead_det_noncegen,"CREATE OR REPLACE FUNCTION vault._crypto_aead_det_noncegen()
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE
AS '$libdir/supabase_vault', $function$pgsodium_crypto_aead_det_noncegen$function$
"
_internal_resolve,"CREATE OR REPLACE FUNCTION graphql._internal_resolve(query text, variables jsonb DEFAULT '{}'::jsonb, ""operationName"" text DEFAULT NULL::text, extensions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE c
AS '$libdir/pg_graphql', $function$resolve_wrapper$function$
"
add_prefixes,"CREATE OR REPLACE FUNCTION storage.add_prefixes(_bucket_id text, _name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    prefixes text[];
BEGIN
    prefixes := ""storage"".""get_prefixes""(""_name"");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, ""_bucket_id"" ON CONFLICT DO NOTHING;
    END IF;
END;
$function$
"
apply_rls,"CREATE OR REPLACE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024))
 RETURNS SETOF realtime.wal_rls
 LANGUAGE plpgsql
AS $function$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_;

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD""T""HH24:MI:SS.MS""Z""'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add ""record"" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add ""old_record"" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '""' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$function$
"
armor,"CREATE OR REPLACE FUNCTION extensions.armor(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$
"
armor,"CREATE OR REPLACE FUNCTION extensions.armor(bytea, text[], text[])
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$
"
broadcast_changes,"CREATE OR REPLACE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$function$
"
build_prepared_statement_sql,"CREATE OR REPLACE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[])
 RETURNS text
 LANGUAGE sql
AS $function$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{""id""}'::text[], '{""bigint""}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $function$
"
can_insert_object,"CREATE OR REPLACE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO ""storage"".""objects"" (""bucket_id"", ""name"", ""owner"", ""metadata"") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$function$
"
cast,"CREATE OR REPLACE FUNCTION realtime.""cast""(val text, type_ regtype)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $function$
"
check_equality_op,"CREATE OR REPLACE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
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
  -- Calcular fondos disponibles
  SELECT (
    -- Ganancias totales (tu lógica semanal)
    COALESCE((SELECT SUM(earning_amount) FROM public.weekly_earnings WHERE user_id = NEW.user_id), 0)
    -
    -- Retiros pagados
    COALESCE((SELECT SUM(monto) FROM public.withdrawals WHERE user_id = NEW.user_id AND estado = 'pagado'), 0)
    -
    -- Retiros pendientes
    COALESCE((SELECT SUM(monto) FROM public.withdrawals WHERE user_id = NEW.user_id AND estado = 'pendiente'), 0)
  ) INTO available_funds;
  
  IF NEW.monto > available_funds THEN
    RAISE EXCEPTION 'Fondos insuficientes. Disponible: %', available_funds;
  END IF;
  
  RETURN NEW;
END;
$function$
"
comment_directive,"CREATE OR REPLACE FUNCTION graphql.comment_directive(comment_ text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
    /*
    comment on column public.account.name is '@graphql.name: myField'
    */
    select
        coalesce(
            (
                regexp_match(
                    comment_,
                    '@graphql\((.+)\)'
                )
            )[1]::jsonb,
            jsonb_build_object()
        )
$function$
"
create_secret,"CREATE OR REPLACE FUNCTION vault.create_secret(new_secret text, new_name text DEFAULT NULL::text, new_description text DEFAULT ''::text, new_key_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  rec record;
BEGIN
  INSERT INTO vault.secrets (secret, name, description)
  VALUES (
    new_secret,
    new_name,
    new_description
  )
  RETURNING * INTO rec;
  UPDATE vault.secrets s
  SET secret = encode(vault._crypto_aead_det_encrypt(
    message := convert_to(rec.secret, 'utf8'),
    additional := convert_to(s.id::text, 'utf8'),
    key_id := 0,
    context := 'pgsodium'::bytea,
    nonce := rec.nonce
  ), 'base64')
  WHERE id = rec.id;
  RETURN rec.id;
END
$function$
"
crypt,"CREATE OR REPLACE FUNCTION extensions.crypt(text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_crypt$function$
"
dearmor,"CREATE OR REPLACE FUNCTION extensions.dearmor(text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_dearmor$function$
"
decrypt,"CREATE OR REPLACE FUNCTION extensions.decrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt$function$
"
decrypt_iv,"CREATE OR REPLACE FUNCTION extensions.decrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt_iv$function$
"
delete_leaf_prefixes,"CREATE OR REPLACE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE ""C"" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE ""C"" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$function$
"
delete_prefix,"CREATE OR REPLACE FUNCTION storage.delete_prefix(_bucket_id text, _name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM ""storage"".""prefixes""
        WHERE ""prefixes"".""bucket_id"" = ""_bucket_id""
          AND level = ""storage"".""get_level""(""_name"") + 1
          AND ""prefixes"".""name"" COLLATE ""C"" LIKE ""_name"" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM ""storage"".""objects""
        WHERE ""objects"".""bucket_id"" = ""_bucket_id""
          AND ""storage"".""get_level""(""objects"".""name"") = ""storage"".""get_level""(""_name"") + 1
          AND ""objects"".""name"" COLLATE ""C"" LIKE ""_name"" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM ""storage"".""prefixes""
        WHERE ""prefixes"".""bucket_id"" = ""_bucket_id""
          AND level = ""storage"".""get_level""(""_name"")
          AND ""prefixes"".""name"" = ""_name"";
        RETURN true;
    END IF;
END;
$function$
"
delete_prefix_hierarchy_trigger,"CREATE OR REPLACE FUNCTION storage.delete_prefix_hierarchy_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    prefix text;
BEGIN
    prefix := ""storage"".""get_prefix""(OLD.""name"");

    IF coalesce(prefix, '') != '' THEN
        PERFORM ""storage"".""delete_prefix""(OLD.""bucket_id"", prefix);
    END IF;

    RETURN OLD;
END;
$function$
"
digest,"CREATE OR REPLACE FUNCTION extensions.digest(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$
"
digest,"CREATE OR REPLACE FUNCTION extensions.digest(text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$
"
email,"CREATE OR REPLACE FUNCTION auth.email()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$function$
"
encrypt,"CREATE OR REPLACE FUNCTION extensions.encrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt$function$
"
encrypt_iv,"CREATE OR REPLACE FUNCTION extensions.encrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt_iv$function$
"
enforce_bucket_name_length,"CREATE OR REPLACE FUNCTION storage.enforce_bucket_name_length()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name ""%"" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$function$
"
exception,"CREATE OR REPLACE FUNCTION graphql.exception(message text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
begin
    raise exception using errcode='22000', message=message;
end;
$function$
"
extension,"CREATE OR REPLACE FUNCTION storage.extension(name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$function$
"
filename,"CREATE OR REPLACE FUNCTION storage.filename(name text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$function$
"
foldername,"CREATE OR REPLACE FUNCTION storage.foldername(name text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
BEGIN
    -- Split on ""/"" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$function$
"
gen_random_bytes,"CREATE OR REPLACE FUNCTION extensions.gen_random_bytes(integer)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_random_bytes$function$
"
gen_random_uuid,"CREATE OR REPLACE FUNCTION extensions.gen_random_uuid()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/pgcrypto', $function$pg_random_uuid$function$
"
gen_salt,"CREATE OR REPLACE FUNCTION extensions.gen_salt(text)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt$function$
"
gen_salt,"CREATE OR REPLACE FUNCTION extensions.gen_salt(text, integer)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt_rounds$function$
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
get_auth,"CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename text)
 RETURNS TABLE(username text, password text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$function$
"
get_available_balance,"CREATE OR REPLACE FUNCTION public.get_available_balance(p_user_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total_earnings NUMERIC;
  v_total_withdrawals NUMERIC;
BEGIN
  -- Sumar todas las ganancias
  SELECT COALESCE(SUM(earning_amount), 0) 
  INTO v_total_earnings
  FROM public.weekly_earnings
  WHERE user_id = p_user_id;
  
  -- Sumar retiros pagados
  SELECT COALESCE(SUM(monto), 0)
  INTO v_total_withdrawals
  FROM public.withdrawals
  WHERE user_id = p_user_id AND estado = 'pagado';
  
  RETURN GREATEST(v_total_earnings - v_total_withdrawals, 0);
END;
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
get_level,"CREATE OR REPLACE FUNCTION storage.get_level(name text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
SELECT array_length(string_to_array(""name"", '/'), 1);
$function$
"
get_prefix,"CREATE OR REPLACE FUNCTION storage.get_prefix(name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
SELECT
    CASE WHEN strpos(""name"", '/') > 0 THEN
             regexp_replace(""name"", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$function$
"
get_prefixes,"CREATE OR REPLACE FUNCTION storage.get_prefixes(name text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE STRICT
AS $function$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array(""name"", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$function$
"
get_schema_version,"CREATE OR REPLACE FUNCTION graphql.get_schema_version()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
    select last_value from graphql.seq_schema_version;
$function$
"
get_size_by_bucket,"CREATE OR REPLACE FUNCTION storage.get_size_by_bucket()
 RETURNS TABLE(size bigint, bucket_id text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from ""storage"".objects as obj
        group by obj.bucket_id;
END
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
grant_pg_cron_access,"CREATE OR REPLACE FUNCTION extensions.grant_pg_cron_access()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$function$
"
grant_pg_graphql_access,"CREATE OR REPLACE FUNCTION extensions.grant_pg_graphql_access()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            ""operationName"" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                ""operationName"" := ""operationName"",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$function$
"
grant_pg_net_access,"CREATE OR REPLACE FUNCTION extensions.grant_pg_net_access()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$function$
"
graphql,"CREATE OR REPLACE FUNCTION graphql_public.graphql(""operationName"" text DEFAULT NULL::text, query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, extensions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
AS $function$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                ""operationName"" := ""operationName"",
                extensions := extensions
            );
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
hmac,"CREATE OR REPLACE FUNCTION extensions.hmac(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$
"
hmac,"CREATE OR REPLACE FUNCTION extensions.hmac(text, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$
"
increment_schema_version,"CREATE OR REPLACE FUNCTION graphql.increment_schema_version()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
    perform pg_catalog.nextval('graphql.seq_schema_version');
end;
$function$
"
initialize_investment,"CREATE OR REPLACE FUNCTION public.initialize_investment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Establecer la fecha de inicio como el inicio de la semana actual
  NEW.last_week_generated := DATE_TRUNC('week', NOW())::DATE - INTERVAL '1 week';
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
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$
"
is_visible_through_filters,"CREATE OR REPLACE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[])
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $function$
"
jwt,"CREATE OR REPLACE FUNCTION auth.jwt()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$
"
list_changes,"CREATE OR REPLACE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer)
 RETURNS SETOF realtime.wal_rls
 LANGUAGE sql
 SET log_min_messages TO 'fatal'
AS $function$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $function$
"
list_multipart_uploads_with_delimiter,"CREATE OR REPLACE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text)
 RETURNS TABLE(key text, id text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE ""C"") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE ""C"" > $4
                            ELSE
                                key COLLATE ""C"" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE ""C"" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE ""C"" ASC, created_at ASC) as e order by key COLLATE ""C"" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$function$
"
list_objects_with_delimiter,"CREATE OR REPLACE FUNCTION storage.list_objects_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text)
 RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE ""C"") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE ""C"" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE ""C"" > $4
                            ELSE
                                name COLLATE ""C"" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE ""C"" ASC) as e order by name COLLATE ""C"" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$function$
"
lock_top_prefixes,"CREATE OR REPLACE FUNCTION storage.lock_top_prefixes(bucket_ids text[], names text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$function$
"
objects_delete_cleanup,"CREATE OR REPLACE FUNCTION storage.objects_delete_cleanup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$function$
"
objects_insert_prefix_trigger,"CREATE OR REPLACE FUNCTION storage.objects_insert_prefix_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM ""storage"".""add_prefixes""(NEW.""bucket_id"", NEW.""name"");
    NEW.level := ""storage"".""get_level""(NEW.""name"");

    RETURN NEW;
END;
$function$
"
objects_update_cleanup,"CREATE OR REPLACE FUNCTION storage.objects_update_cleanup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$function$
"
objects_update_level_trigger,"CREATE OR REPLACE FUNCTION storage.objects_update_level_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW.""name"" <> OLD.""name"" OR NEW.""bucket_id"" <> OLD.""bucket_id"") THEN
        -- Set the new level
        NEW.""level"" := ""storage"".""get_level""(NEW.""name"");
    END IF;
    RETURN NEW;
END;
$function$
"
objects_update_prefix_trigger,"CREATE OR REPLACE FUNCTION storage.objects_update_prefix_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW.""name"" <> OLD.""name"" OR NEW.""bucket_id"" <> OLD.""bucket_id"") THEN
        -- Retrieve old prefixes
        old_prefixes := ""storage"".""get_prefixes""(OLD.""name"");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM ""storage"".""objects""
                 WHERE ""bucket_id"" = OLD.""bucket_id""
                   AND ""name"" <> OLD.""name""
                   AND ""name"" LIKE (prefix || '%')
             )
         )
        DELETE FROM ""storage"".""prefixes"" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM ""storage"".""add_prefixes""(NEW.""bucket_id"", NEW.""name"");
    END IF;
    -- Set the new level
    NEW.""level"" := ""storage"".""get_level""(NEW.""name"");

    RETURN NEW;
END;
$function$
"
operation,"CREATE OR REPLACE FUNCTION storage.operation()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$function$
"
pg_stat_statements,"CREATE OR REPLACE FUNCTION extensions.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT shared_blk_read_time double precision, OUT shared_blk_write_time double precision, OUT local_blk_read_time double precision, OUT local_blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision, OUT jit_deform_count bigint, OUT jit_deform_time double precision, OUT stats_since timestamp with time zone, OUT minmax_stats_since timestamp with time zone)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_1_11$function$
"
pg_stat_statements_info,"CREATE OR REPLACE FUNCTION extensions.pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone)
 RETURNS record
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_info$function$
"
pg_stat_statements_reset,"CREATE OR REPLACE FUNCTION extensions.pg_stat_statements_reset(userid oid DEFAULT 0, dbid oid DEFAULT 0, queryid bigint DEFAULT 0, minmax_only boolean DEFAULT false)
 RETURNS timestamp with time zone
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_reset_1_11$function$
"
pgp_armor_headers,"CREATE OR REPLACE FUNCTION extensions.pgp_armor_headers(text, OUT key text, OUT value text)
 RETURNS SETOF record
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_armor_headers$function$
"
pgp_key_id,"CREATE OR REPLACE FUNCTION extensions.pgp_key_id(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_key_id_w$function$
"
pgp_pub_decrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt(bytea, bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
"
pgp_pub_decrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
"
pgp_pub_decrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
"
pgp_pub_decrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
"
pgp_pub_decrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
"
pgp_pub_decrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
"
pgp_pub_encrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt(text, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$
"
pgp_pub_encrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt(text, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$
"
pgp_pub_encrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$
"
pgp_pub_encrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$
"
pgp_sym_decrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt(bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$
"
pgp_sym_decrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt(bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$
"
pgp_sym_decrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$
"
pgp_sym_decrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$
"
pgp_sym_encrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt(text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$
"
pgp_sym_encrypt,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt(text, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$
"
pgp_sym_encrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$
"
pgp_sym_encrypt_bytea,"CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$
"
pgrst_ddl_watch,"CREATE OR REPLACE FUNCTION extensions.pgrst_ddl_watch()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $function$
"
pgrst_drop_watch,"CREATE OR REPLACE FUNCTION extensions.pgrst_drop_watch()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $function$
"
prefixes_delete_cleanup,"CREATE OR REPLACE FUNCTION storage.prefixes_delete_cleanup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$function$
"
prefixes_insert_trigger,"CREATE OR REPLACE FUNCTION storage.prefixes_insert_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM ""storage"".""add_prefixes""(NEW.""bucket_id"", NEW.""name"");
    RETURN NEW;
END;
$function$
"
quote_wal2json,"CREATE OR REPLACE FUNCTION realtime.quote_wal2json(entity regclass)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE STRICT
AS $function$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '""')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '""'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '""')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '""'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $function$
"
resolve,"CREATE OR REPLACE FUNCTION graphql.resolve(query text, variables jsonb DEFAULT '{}'::jsonb, ""operationName"" text DEFAULT NULL::text, extensions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare
    res jsonb;
    message_text text;
begin
  begin
    select graphql._internal_resolve(""query"" := ""query"",
                                     ""variables"" := ""variables"",
                                     ""operationName"" := ""operationName"",
                                     ""extensions"" := ""extensions"") into res;
    return res;
  exception
    when others then
    get stacked diagnostics message_text = message_text;
    return
    jsonb_build_object('data', null,
                       'errors', jsonb_build_array(jsonb_build_object('message', message_text)));
  end;
end;
$function$
"
role,"CREATE OR REPLACE FUNCTION auth.role()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$function$
"
search,"CREATE OR REPLACE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
AS $function$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$function$
"
search_legacy_v1,"CREATE OR REPLACE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as ""name"",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as ""name"",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$function$
"
search_v1_optimised,"CREATE OR REPLACE FUNCTION storage.search_v1_optimised(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as ""name"",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$function$
"
search_v2,"CREATE OR REPLACE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text)
 RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE ""C"") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE ""C"" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE ""C"" %s $5)', cursor_op);
        sort_expr := format('name COLLATE ""C"" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE ""C"" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE ""C"" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$function$
"
send,"CREATE OR REPLACE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$function$
"
set_graphql_placeholder,"CREATE OR REPLACE FUNCTION extensions.set_graphql_placeholder()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            ""operationName"" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$function$
"
subscription_check_filters,"CREATE OR REPLACE FUNCTION realtime.subscription_check_filters()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $function$
"
to_regrole,"CREATE OR REPLACE FUNCTION realtime.to_regrole(role_name text)
 RETURNS regrole
 LANGUAGE sql
 IMMUTABLE
AS $function$ select role_name::regrole $function$
"
topic,"CREATE OR REPLACE FUNCTION realtime.topic()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
select nullif(current_setting('realtime.topic', true), '')::text;
$function$
"
uid,"CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$
"
update_secret,"CREATE OR REPLACE FUNCTION vault.update_secret(secret_id uuid, new_secret text DEFAULT NULL::text, new_name text DEFAULT NULL::text, new_description text DEFAULT NULL::text, new_key_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  decrypted_secret text := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE id = secret_id);
BEGIN
  UPDATE vault.secrets s
  SET
    secret = CASE WHEN new_secret IS NULL THEN s.secret
                  ELSE encode(vault._crypto_aead_det_encrypt(
                    message := convert_to(new_secret, 'utf8'),
                    additional := convert_to(s.id::text, 'utf8'),
                    key_id := 0,
                    context := 'pgsodium'::bytea,
                    nonce := s.nonce
                  ), 'base64') END,
    name = coalesce(new_name, s.name),
    description = coalesce(new_description, s.description),
    updated_at = now()
  WHERE s.id = secret_id;
END
$function$
"
update_updated_at_column,"CREATE OR REPLACE FUNCTION storage.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$function$
"
uuid_generate_v1,"CREATE OR REPLACE FUNCTION extensions.uuid_generate_v1()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1$function$
"
uuid_generate_v1mc,"CREATE OR REPLACE FUNCTION extensions.uuid_generate_v1mc()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1mc$function$
"
uuid_generate_v3,"CREATE OR REPLACE FUNCTION extensions.uuid_generate_v3(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v3$function$
"
uuid_generate_v4,"CREATE OR REPLACE FUNCTION extensions.uuid_generate_v4()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$
"
uuid_generate_v5,"CREATE OR REPLACE FUNCTION extensions.uuid_generate_v5(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v5$function$
"
uuid_nil,"CREATE OR REPLACE FUNCTION extensions.uuid_nil()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_nil$function$
"
uuid_ns_dns,"CREATE OR REPLACE FUNCTION extensions.uuid_ns_dns()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_dns$function$
"
uuid_ns_oid,"CREATE OR REPLACE FUNCTION extensions.uuid_ns_oid()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_oid$function$
"
uuid_ns_url,"CREATE OR REPLACE FUNCTION extensions.uuid_ns_url()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_url$function$
"
uuid_ns_x500,"CREATE OR REPLACE FUNCTION extensions.uuid_ns_x500()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_x500$function$
"

// TRIGGER

trigger_name,table_name,schema_name,definition
enforce_bucket_name_length_trigger,buckets,storage,CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length()
on_investment_created,investments,public,CREATE TRIGGER on_investment_created BEFORE INSERT ON investments FOR EACH ROW EXECUTE FUNCTION initialize_investment()
objects_delete_delete_prefix,objects,storage,CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger()
objects_insert_create_prefix,objects,storage,CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger()
objects_update_create_prefix,objects,storage,CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (new.name <> old.name OR new.bucket_id <> old.bucket_id) EXECUTE FUNCTION storage.objects_update_prefix_trigger()
update_objects_updated_at,objects,storage,CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column()
prefixes_create_hierarchy,prefixes,storage,CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN (pg_trigger_depth() < 1) EXECUTE FUNCTION storage.prefixes_insert_trigger()
prefixes_delete_hierarchy,prefixes,storage,CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger()
tr_check_filters,subscription,realtime,CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters()
on_auth_user_created,users,auth,CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()
validate_withdrawal_funds,withdrawals,public,CREATE TRIGGER validate_withdrawal_funds BEFORE INSERT ON withdrawals FOR EACH ROW EXECUTE FUNCTION check_sufficient_funds()


//INDICES 



table_name,index_name,definition
audit_log_entries,audit_log_entries_pkey,CREATE UNIQUE INDEX audit_log_entries_pkey ON auth.audit_log_entries USING btree (id)
audit_log_entries,audit_logs_instance_id_idx,CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id)
buckets,bname,CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name)
buckets,buckets_pkey,CREATE UNIQUE INDEX buckets_pkey ON storage.buckets USING btree (id)
buckets_analytics,buckets_analytics_pkey,CREATE UNIQUE INDEX buckets_analytics_pkey ON storage.buckets_analytics USING btree (id)
buckets_analytics,buckets_analytics_unique_name_idx,CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL)
buckets_vectors,buckets_vectors_pkey,CREATE UNIQUE INDEX buckets_vectors_pkey ON storage.buckets_vectors USING btree (id)
flow_state,flow_state_created_at_idx,CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC)
flow_state,flow_state_pkey,CREATE UNIQUE INDEX flow_state_pkey ON auth.flow_state USING btree (id)
flow_state,idx_auth_code,CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code)
flow_state,idx_user_id_auth_method,"CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method)"
identities,identities_email_idx,CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops)
identities,identities_pkey,CREATE UNIQUE INDEX identities_pkey ON auth.identities USING btree (id)
identities,identities_provider_id_provider_unique,"CREATE UNIQUE INDEX identities_provider_id_provider_unique ON auth.identities USING btree (provider_id, provider)"
identities,identities_user_id_idx,CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id)
instances,instances_pkey,CREATE UNIQUE INDEX instances_pkey ON auth.instances USING btree (id)
investments,idx_investments_created_at,CREATE INDEX idx_investments_created_at ON public.investments USING btree (created_at DESC)
investments,idx_investments_user_created,"CREATE INDEX idx_investments_user_created ON public.investments USING btree (user_id, created_at DESC)"
investments,investments_pkey,CREATE UNIQUE INDEX investments_pkey ON public.investments USING btree (id)
messages,messages_inserted_at_topic_index,"CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE))"
messages,messages_pkey,"CREATE UNIQUE INDEX messages_pkey ON ONLY realtime.messages USING btree (id, inserted_at)"
mfa_amr_claims,amr_id_pk,CREATE UNIQUE INDEX amr_id_pk ON auth.mfa_amr_claims USING btree (id)
mfa_amr_claims,mfa_amr_claims_session_id_authentication_method_pkey,"CREATE UNIQUE INDEX mfa_amr_claims_session_id_authentication_method_pkey ON auth.mfa_amr_claims USING btree (session_id, authentication_method)"
mfa_challenges,mfa_challenge_created_at_idx,CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC)
mfa_challenges,mfa_challenges_pkey,CREATE UNIQUE INDEX mfa_challenges_pkey ON auth.mfa_challenges USING btree (id)
mfa_factors,factor_id_created_at_idx,"CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at)"
mfa_factors,mfa_factors_last_challenged_at_key,CREATE UNIQUE INDEX mfa_factors_last_challenged_at_key ON auth.mfa_factors USING btree (last_challenged_at)
mfa_factors,mfa_factors_pkey,CREATE UNIQUE INDEX mfa_factors_pkey ON auth.mfa_factors USING btree (id)
mfa_factors,mfa_factors_user_friendly_name_unique,"CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text)"
mfa_factors,mfa_factors_user_id_idx,CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id)
mfa_factors,unique_phone_factor_per_user,"CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone)"
migrations,migrations_name_key,CREATE UNIQUE INDEX migrations_name_key ON storage.migrations USING btree (name)
migrations,migrations_pkey,CREATE UNIQUE INDEX migrations_pkey ON storage.migrations USING btree (id)
oauth_authorizations,oauth_auth_pending_exp_idx,CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status)
oauth_authorizations,oauth_authorizations_authorization_code_key,CREATE UNIQUE INDEX oauth_authorizations_authorization_code_key ON auth.oauth_authorizations USING btree (authorization_code)
oauth_authorizations,oauth_authorizations_authorization_id_key,CREATE UNIQUE INDEX oauth_authorizations_authorization_id_key ON auth.oauth_authorizations USING btree (authorization_id)
oauth_authorizations,oauth_authorizations_pkey,CREATE UNIQUE INDEX oauth_authorizations_pkey ON auth.oauth_authorizations USING btree (id)
oauth_clients,oauth_clients_deleted_at_idx,CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at)
oauth_clients,oauth_clients_pkey,CREATE UNIQUE INDEX oauth_clients_pkey ON auth.oauth_clients USING btree (id)
oauth_consents,oauth_consents_active_client_idx,CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL)
oauth_consents,oauth_consents_active_user_client_idx,"CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL)"
oauth_consents,oauth_consents_pkey,CREATE UNIQUE INDEX oauth_consents_pkey ON auth.oauth_consents USING btree (id)
oauth_consents,oauth_consents_user_client_unique,"CREATE UNIQUE INDEX oauth_consents_user_client_unique ON auth.oauth_consents USING btree (user_id, client_id)"
oauth_consents,oauth_consents_user_order_idx,"CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC)"
objects,bucketid_objname,"CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name)"
objects,idx_name_bucket_level_unique,"CREATE UNIQUE INDEX idx_name_bucket_level_unique ON storage.objects USING btree (name COLLATE ""C"", bucket_id, level)"
objects,idx_objects_bucket_id_name,"CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE ""C"")"
objects,idx_objects_lower_name,"CREATE INDEX idx_objects_lower_name ON storage.objects USING btree ((path_tokens[level]), lower(name) text_pattern_ops, bucket_id, level)"
objects,name_prefix_search,CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops)
objects,objects_bucket_id_level_idx,"CREATE UNIQUE INDEX objects_bucket_id_level_idx ON storage.objects USING btree (bucket_id, level, name COLLATE ""C"")"
objects,objects_pkey,CREATE UNIQUE INDEX objects_pkey ON storage.objects USING btree (id)
one_time_tokens,one_time_tokens_pkey,CREATE UNIQUE INDEX one_time_tokens_pkey ON auth.one_time_tokens USING btree (id)
one_time_tokens,one_time_tokens_relates_to_hash_idx,CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to)
one_time_tokens,one_time_tokens_token_hash_hash_idx,CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash)
one_time_tokens,one_time_tokens_user_id_token_type_key,"CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type)"
pg_toast_1213,pg_toast_1213_index,"CREATE UNIQUE INDEX pg_toast_1213_index ON pg_toast.pg_toast_1213 USING btree (chunk_id, chunk_seq)"
pg_toast_1247,pg_toast_1247_index,"CREATE UNIQUE INDEX pg_toast_1247_index ON pg_toast.pg_toast_1247 USING btree (chunk_id, chunk_seq)"
pg_toast_1255,pg_toast_1255_index,"CREATE UNIQUE INDEX pg_toast_1255_index ON pg_toast.pg_toast_1255 USING btree (chunk_id, chunk_seq)"
pg_toast_1260,pg_toast_1260_index,"CREATE UNIQUE INDEX pg_toast_1260_index ON pg_toast.pg_toast_1260 USING btree (chunk_id, chunk_seq)"
pg_toast_1262,pg_toast_1262_index,"CREATE UNIQUE INDEX pg_toast_1262_index ON pg_toast.pg_toast_1262 USING btree (chunk_id, chunk_seq)"
pg_toast_13402,pg_toast_13402_index,"CREATE UNIQUE INDEX pg_toast_13402_index ON pg_toast.pg_toast_13402 USING btree (chunk_id, chunk_seq)"
pg_toast_13407,pg_toast_13407_index,"CREATE UNIQUE INDEX pg_toast_13407_index ON pg_toast.pg_toast_13407 USING btree (chunk_id, chunk_seq)"
pg_toast_13412,pg_toast_13412_index,"CREATE UNIQUE INDEX pg_toast_13412_index ON pg_toast.pg_toast_13412 USING btree (chunk_id, chunk_seq)"
pg_toast_13417,pg_toast_13417_index,"CREATE UNIQUE INDEX pg_toast_13417_index ON pg_toast.pg_toast_13417 USING btree (chunk_id, chunk_seq)"
pg_toast_1417,pg_toast_1417_index,"CREATE UNIQUE INDEX pg_toast_1417_index ON pg_toast.pg_toast_1417 USING btree (chunk_id, chunk_seq)"
pg_toast_1418,pg_toast_1418_index,"CREATE UNIQUE INDEX pg_toast_1418_index ON pg_toast.pg_toast_1418 USING btree (chunk_id, chunk_seq)"
pg_toast_16495,pg_toast_16495_index,"CREATE UNIQUE INDEX pg_toast_16495_index ON pg_toast.pg_toast_16495 USING btree (chunk_id, chunk_seq)"
pg_toast_16507,pg_toast_16507_index,"CREATE UNIQUE INDEX pg_toast_16507_index ON pg_toast.pg_toast_16507 USING btree (chunk_id, chunk_seq)"
pg_toast_16518,pg_toast_16518_index,"CREATE UNIQUE INDEX pg_toast_16518_index ON pg_toast.pg_toast_16518 USING btree (chunk_id, chunk_seq)"
pg_toast_16525,pg_toast_16525_index,"CREATE UNIQUE INDEX pg_toast_16525_index ON pg_toast.pg_toast_16525 USING btree (chunk_id, chunk_seq)"
pg_toast_16546,pg_toast_16546_index,"CREATE UNIQUE INDEX pg_toast_16546_index ON pg_toast.pg_toast_16546 USING btree (chunk_id, chunk_seq)"
pg_toast_16561,pg_toast_16561_index,"CREATE UNIQUE INDEX pg_toast_16561_index ON pg_toast.pg_toast_16561 USING btree (chunk_id, chunk_seq)"
pg_toast_16658,pg_toast_16658_index,"CREATE UNIQUE INDEX pg_toast_16658_index ON pg_toast.pg_toast_16658 USING btree (chunk_id, chunk_seq)"
pg_toast_16727,pg_toast_16727_index,"CREATE UNIQUE INDEX pg_toast_16727_index ON pg_toast.pg_toast_16727 USING btree (chunk_id, chunk_seq)"
pg_toast_16757,pg_toast_16757_index,"CREATE UNIQUE INDEX pg_toast_16757_index ON pg_toast.pg_toast_16757 USING btree (chunk_id, chunk_seq)"
pg_toast_16791,pg_toast_16791_index,"CREATE UNIQUE INDEX pg_toast_16791_index ON pg_toast.pg_toast_16791 USING btree (chunk_id, chunk_seq)"
pg_toast_16804,pg_toast_16804_index,"CREATE UNIQUE INDEX pg_toast_16804_index ON pg_toast.pg_toast_16804 USING btree (chunk_id, chunk_seq)"
pg_toast_16816,pg_toast_16816_index,"CREATE UNIQUE INDEX pg_toast_16816_index ON pg_toast.pg_toast_16816 USING btree (chunk_id, chunk_seq)"
pg_toast_16834,pg_toast_16834_index,"CREATE UNIQUE INDEX pg_toast_16834_index ON pg_toast.pg_toast_16834 USING btree (chunk_id, chunk_seq)"
pg_toast_16843,pg_toast_16843_index,"CREATE UNIQUE INDEX pg_toast_16843_index ON pg_toast.pg_toast_16843 USING btree (chunk_id, chunk_seq)"
pg_toast_16858,pg_toast_16858_index,"CREATE UNIQUE INDEX pg_toast_16858_index ON pg_toast.pg_toast_16858 USING btree (chunk_id, chunk_seq)"
pg_toast_16876,pg_toast_16876_index,"CREATE UNIQUE INDEX pg_toast_16876_index ON pg_toast.pg_toast_16876 USING btree (chunk_id, chunk_seq)"
pg_toast_16929,pg_toast_16929_index,"CREATE UNIQUE INDEX pg_toast_16929_index ON pg_toast.pg_toast_16929 USING btree (chunk_id, chunk_seq)"
pg_toast_16979,pg_toast_16979_index,"CREATE UNIQUE INDEX pg_toast_16979_index ON pg_toast.pg_toast_16979 USING btree (chunk_id, chunk_seq)"
pg_toast_17011,pg_toast_17011_index,"CREATE UNIQUE INDEX pg_toast_17011_index ON pg_toast.pg_toast_17011 USING btree (chunk_id, chunk_seq)"
pg_toast_17041,pg_toast_17041_index,"CREATE UNIQUE INDEX pg_toast_17041_index ON pg_toast.pg_toast_17041 USING btree (chunk_id, chunk_seq)"
pg_toast_17074,pg_toast_17074_index,"CREATE UNIQUE INDEX pg_toast_17074_index ON pg_toast.pg_toast_17074 USING btree (chunk_id, chunk_seq)"
pg_toast_17149,pg_toast_17149_index,"CREATE UNIQUE INDEX pg_toast_17149_index ON pg_toast.pg_toast_17149 USING btree (chunk_id, chunk_seq)"
pg_toast_17163,pg_toast_17163_index,"CREATE UNIQUE INDEX pg_toast_17163_index ON pg_toast.pg_toast_17163 USING btree (chunk_id, chunk_seq)"
pg_toast_17202,pg_toast_17202_index,"CREATE UNIQUE INDEX pg_toast_17202_index ON pg_toast.pg_toast_17202 USING btree (chunk_id, chunk_seq)"
pg_toast_17246,pg_toast_17246_index,"CREATE UNIQUE INDEX pg_toast_17246_index ON pg_toast.pg_toast_17246 USING btree (chunk_id, chunk_seq)"
pg_toast_17273,pg_toast_17273_index,"CREATE UNIQUE INDEX pg_toast_17273_index ON pg_toast.pg_toast_17273 USING btree (chunk_id, chunk_seq)"
pg_toast_17283,pg_toast_17283_index,"CREATE UNIQUE INDEX pg_toast_17283_index ON pg_toast.pg_toast_17283 USING btree (chunk_id, chunk_seq)"
pg_toast_17325,pg_toast_17325_index,"CREATE UNIQUE INDEX pg_toast_17325_index ON pg_toast.pg_toast_17325 USING btree (chunk_id, chunk_seq)"
pg_toast_17487,pg_toast_17487_index,"CREATE UNIQUE INDEX pg_toast_17487_index ON pg_toast.pg_toast_17487 USING btree (chunk_id, chunk_seq)"
pg_toast_17505,pg_toast_17505_index,"CREATE UNIQUE INDEX pg_toast_17505_index ON pg_toast.pg_toast_17505 USING btree (chunk_id, chunk_seq)"
pg_toast_17523,pg_toast_17523_index,"CREATE UNIQUE INDEX pg_toast_17523_index ON pg_toast.pg_toast_17523 USING btree (chunk_id, chunk_seq)"
pg_toast_2328,pg_toast_2328_index,"CREATE UNIQUE INDEX pg_toast_2328_index ON pg_toast.pg_toast_2328 USING btree (chunk_id, chunk_seq)"
pg_toast_2396,pg_toast_2396_index,"CREATE UNIQUE INDEX pg_toast_2396_index ON pg_toast.pg_toast_2396 USING btree (chunk_id, chunk_seq)"
pg_toast_2600,pg_toast_2600_index,"CREATE UNIQUE INDEX pg_toast_2600_index ON pg_toast.pg_toast_2600 USING btree (chunk_id, chunk_seq)"
pg_toast_2604,pg_toast_2604_index,"CREATE UNIQUE INDEX pg_toast_2604_index ON pg_toast.pg_toast_2604 USING btree (chunk_id, chunk_seq)"
pg_toast_2606,pg_toast_2606_index,"CREATE UNIQUE INDEX pg_toast_2606_index ON pg_toast.pg_toast_2606 USING btree (chunk_id, chunk_seq)"
pg_toast_2609,pg_toast_2609_index,"CREATE UNIQUE INDEX pg_toast_2609_index ON pg_toast.pg_toast_2609 USING btree (chunk_id, chunk_seq)"
pg_toast_2612,pg_toast_2612_index,"CREATE UNIQUE INDEX pg_toast_2612_index ON pg_toast.pg_toast_2612 USING btree (chunk_id, chunk_seq)"
pg_toast_26148,pg_toast_26148_index,"CREATE UNIQUE INDEX pg_toast_26148_index ON pg_toast.pg_toast_26148 USING btree (chunk_id, chunk_seq)"
pg_toast_2615,pg_toast_2615_index,"CREATE UNIQUE INDEX pg_toast_2615_index ON pg_toast.pg_toast_2615 USING btree (chunk_id, chunk_seq)"
pg_toast_2618,pg_toast_2618_index,"CREATE UNIQUE INDEX pg_toast_2618_index ON pg_toast.pg_toast_2618 USING btree (chunk_id, chunk_seq)"
pg_toast_2619,pg_toast_2619_index,"CREATE UNIQUE INDEX pg_toast_2619_index ON pg_toast.pg_toast_2619 USING btree (chunk_id, chunk_seq)"
pg_toast_2620,pg_toast_2620_index,"CREATE UNIQUE INDEX pg_toast_2620_index ON pg_toast.pg_toast_2620 USING btree (chunk_id, chunk_seq)"
pg_toast_2964,pg_toast_2964_index,"CREATE UNIQUE INDEX pg_toast_2964_index ON pg_toast.pg_toast_2964 USING btree (chunk_id, chunk_seq)"
pg_toast_3079,pg_toast_3079_index,"CREATE UNIQUE INDEX pg_toast_3079_index ON pg_toast.pg_toast_3079 USING btree (chunk_id, chunk_seq)"
pg_toast_3118,pg_toast_3118_index,"CREATE UNIQUE INDEX pg_toast_3118_index ON pg_toast.pg_toast_3118 USING btree (chunk_id, chunk_seq)"
pg_toast_3256,pg_toast_3256_index,"CREATE UNIQUE INDEX pg_toast_3256_index ON pg_toast.pg_toast_3256 USING btree (chunk_id, chunk_seq)"
pg_toast_3350,pg_toast_3350_index,"CREATE UNIQUE INDEX pg_toast_3350_index ON pg_toast.pg_toast_3350 USING btree (chunk_id, chunk_seq)"
pg_toast_3381,pg_toast_3381_index,"CREATE UNIQUE INDEX pg_toast_3381_index ON pg_toast.pg_toast_3381 USING btree (chunk_id, chunk_seq)"
pg_toast_3394,pg_toast_3394_index,"CREATE UNIQUE INDEX pg_toast_3394_index ON pg_toast.pg_toast_3394 USING btree (chunk_id, chunk_seq)"
pg_toast_3429,pg_toast_3429_index,"CREATE UNIQUE INDEX pg_toast_3429_index ON pg_toast.pg_toast_3429 USING btree (chunk_id, chunk_seq)"
pg_toast_3456,pg_toast_3456_index,"CREATE UNIQUE INDEX pg_toast_3456_index ON pg_toast.pg_toast_3456 USING btree (chunk_id, chunk_seq)"
pg_toast_3466,pg_toast_3466_index,"CREATE UNIQUE INDEX pg_toast_3466_index ON pg_toast.pg_toast_3466 USING btree (chunk_id, chunk_seq)"
pg_toast_3592,pg_toast_3592_index,"CREATE UNIQUE INDEX pg_toast_3592_index ON pg_toast.pg_toast_3592 USING btree (chunk_id, chunk_seq)"
pg_toast_3596,pg_toast_3596_index,"CREATE UNIQUE INDEX pg_toast_3596_index ON pg_toast.pg_toast_3596 USING btree (chunk_id, chunk_seq)"
pg_toast_3600,pg_toast_3600_index,"CREATE UNIQUE INDEX pg_toast_3600_index ON pg_toast.pg_toast_3600 USING btree (chunk_id, chunk_seq)"
pg_toast_6000,pg_toast_6000_index,"CREATE UNIQUE INDEX pg_toast_6000_index ON pg_toast.pg_toast_6000 USING btree (chunk_id, chunk_seq)"
pg_toast_6100,pg_toast_6100_index,"CREATE UNIQUE INDEX pg_toast_6100_index ON pg_toast.pg_toast_6100 USING btree (chunk_id, chunk_seq)"
pg_toast_6106,pg_toast_6106_index,"CREATE UNIQUE INDEX pg_toast_6106_index ON pg_toast.pg_toast_6106 USING btree (chunk_id, chunk_seq)"
pg_toast_6243,pg_toast_6243_index,"CREATE UNIQUE INDEX pg_toast_6243_index ON pg_toast.pg_toast_6243 USING btree (chunk_id, chunk_seq)"
pg_toast_826,pg_toast_826_index,"CREATE UNIQUE INDEX pg_toast_826_index ON pg_toast.pg_toast_826 USING btree (chunk_id, chunk_seq)"
prefixes,idx_prefixes_lower_name,"CREATE INDEX idx_prefixes_lower_name ON storage.prefixes USING btree (bucket_id, level, ((string_to_array(name, '/'::text))[level]), lower(name) text_pattern_ops)"
prefixes,prefixes_pkey,"CREATE UNIQUE INDEX prefixes_pkey ON storage.prefixes USING btree (bucket_id, level, name)"
profiles,idx_profiles_created_at,CREATE INDEX idx_profiles_created_at ON public.profiles USING btree (created_at DESC)
profiles,idx_profiles_role,CREATE INDEX idx_profiles_role ON public.profiles USING btree (role)
profiles,profiles_email_key,CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email)
profiles,profiles_pkey,CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)
refresh_tokens,refresh_tokens_instance_id_idx,CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id)
refresh_tokens,refresh_tokens_instance_id_user_id_idx,"CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id)"
refresh_tokens,refresh_tokens_parent_idx,CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent)
refresh_tokens,refresh_tokens_pkey,CREATE UNIQUE INDEX refresh_tokens_pkey ON auth.refresh_tokens USING btree (id)
refresh_tokens,refresh_tokens_session_id_revoked_idx,"CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked)"
refresh_tokens,refresh_tokens_token_unique,CREATE UNIQUE INDEX refresh_tokens_token_unique ON auth.refresh_tokens USING btree (token)
refresh_tokens,refresh_tokens_updated_at_idx,CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC)
s3_multipart_uploads,idx_multipart_uploads_list,"CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at)"
s3_multipart_uploads,s3_multipart_uploads_pkey,CREATE UNIQUE INDEX s3_multipart_uploads_pkey ON storage.s3_multipart_uploads USING btree (id)
s3_multipart_uploads_parts,s3_multipart_uploads_parts_pkey,CREATE UNIQUE INDEX s3_multipart_uploads_parts_pkey ON storage.s3_multipart_uploads_parts USING btree (id)
saml_providers,saml_providers_entity_id_key,CREATE UNIQUE INDEX saml_providers_entity_id_key ON auth.saml_providers USING btree (entity_id)
saml_providers,saml_providers_pkey,CREATE UNIQUE INDEX saml_providers_pkey ON auth.saml_providers USING btree (id)
saml_providers,saml_providers_sso_provider_id_idx,CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id)
saml_relay_states,saml_relay_states_created_at_idx,CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC)
saml_relay_states,saml_relay_states_for_email_idx,CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email)
saml_relay_states,saml_relay_states_pkey,CREATE UNIQUE INDEX saml_relay_states_pkey ON auth.saml_relay_states USING btree (id)
saml_relay_states,saml_relay_states_sso_provider_id_idx,CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id)
schema_migrations,schema_migrations_pkey,CREATE UNIQUE INDEX schema_migrations_pkey ON auth.schema_migrations USING btree (version)
schema_migrations,schema_migrations_pkey,CREATE UNIQUE INDEX schema_migrations_pkey ON realtime.schema_migrations USING btree (version)
secrets,secrets_name_idx,CREATE UNIQUE INDEX secrets_name_idx ON vault.secrets USING btree (name) WHERE (name IS NOT NULL)
secrets,secrets_pkey,CREATE UNIQUE INDEX secrets_pkey ON vault.secrets USING btree (id)
sessions,sessions_not_after_idx,CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC)
sessions,sessions_oauth_client_id_idx,CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id)
sessions,sessions_pkey,CREATE UNIQUE INDEX sessions_pkey ON auth.sessions USING btree (id)
sessions,sessions_user_id_idx,CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id)
sessions,user_id_created_at_idx,"CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at)"
sso_domains,sso_domains_domain_idx,CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain))
sso_domains,sso_domains_pkey,CREATE UNIQUE INDEX sso_domains_pkey ON auth.sso_domains USING btree (id)
sso_domains,sso_domains_sso_provider_id_idx,CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id)
sso_providers,sso_providers_pkey,CREATE UNIQUE INDEX sso_providers_pkey ON auth.sso_providers USING btree (id)
sso_providers,sso_providers_resource_id_idx,CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id))
sso_providers,sso_providers_resource_id_pattern_idx,CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops)
subscription,ix_realtime_subscription_entity,CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity)
subscription,pk_subscription,CREATE UNIQUE INDEX pk_subscription ON realtime.subscription USING btree (id)
subscription,subscription_subscription_id_entity_filters_key,"CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_key ON realtime.subscription USING btree (subscription_id, entity, filters)"
users,confirmation_token_idx,CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text)
users,email_change_token_current_idx,CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text)
users,email_change_token_new_idx,CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text)
users,reauthentication_token_idx,CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text)
users,recovery_token_idx,CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text)
users,users_email_partial_key,CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false)
users,users_instance_id_email_idx,"CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text))"
users,users_instance_id_idx,CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id)
users,users_is_anonymous_idx,CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous)
users,users_phone_key,CREATE UNIQUE INDEX users_phone_key ON auth.users USING btree (phone)
users,users_pkey,CREATE UNIQUE INDEX users_pkey ON auth.users USING btree (id)
vector_indexes,vector_indexes_name_bucket_id_idx,"CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id)"
vector_indexes,vector_indexes_pkey,CREATE UNIQUE INDEX vector_indexes_pkey ON storage.vector_indexes USING btree (id)
weekly_earnings,idx_weekly_earnings_dates,"CREATE INDEX idx_weekly_earnings_dates ON public.weekly_earnings USING btree (week_start, week_end)"
weekly_earnings,idx_weekly_earnings_user,CREATE INDEX idx_weekly_earnings_user ON public.weekly_earnings USING btree (user_id)
weekly_earnings,unique_user_week,"CREATE UNIQUE INDEX unique_user_week ON public.weekly_earnings USING btree (user_id, week_start)"
weekly_earnings,weekly_earnings_pkey,CREATE UNIQUE INDEX weekly_earnings_pkey ON public.weekly_earnings USING btree (id)
withdrawals,idx_withdrawals_estado,CREATE INDEX idx_withdrawals_estado ON public.withdrawals USING btree (estado)
withdrawals,idx_withdrawals_estado_fecha,"CREATE INDEX idx_withdrawals_estado_fecha ON public.withdrawals USING btree (estado, fecha_solicitud DESC)"
withdrawals,idx_withdrawals_fecha_solicitud,CREATE INDEX idx_withdrawals_fecha_solicitud ON public.withdrawals USING btree (fecha_solicitud DESC)
withdrawals,idx_withdrawals_user_estado,"CREATE INDEX idx_withdrawals_user_estado ON public.withdrawals USING btree (user_id, estado)"
withdrawals,idx_withdrawals_user_id,CREATE INDEX idx_withdrawals_user_id ON public.withdrawals USING btree (user_id)
withdrawals,withdrawals_pkey,CREATE UNIQUE INDEX withdrawals_pkey ON public.withdrawals USING btree (id)




// views 


table_name,view_definition
pg_stat_statements_info," SELECT dealloc,
    stats_reset
   FROM pg_stat_statements_info() pg_stat_statements_info(dealloc, stats_reset);"
pg_stat_statements," SELECT userid,
    dbid,
    toplevel,
    queryid,
    query,
    plans,
    total_plan_time,
    min_plan_time,
    max_plan_time,
    mean_plan_time,
    stddev_plan_time,
    calls,
    total_exec_time,
    min_exec_time,
    max_exec_time,
    mean_exec_time,
    stddev_exec_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    shared_blks_dirtied,
    shared_blks_written,
    local_blks_hit,
    local_blks_read,
    local_blks_dirtied,
    local_blks_written,
    temp_blks_read,
    temp_blks_written,
    shared_blk_read_time,
    shared_blk_write_time,
    local_blk_read_time,
    local_blk_write_time,
    temp_blk_read_time,
    temp_blk_write_time,
    wal_records,
    wal_fpi,
    wal_bytes,
    jit_functions,
    jit_generation_time,
    jit_inlining_count,
    jit_inlining_time,
    jit_optimization_count,
    jit_optimization_time,
    jit_emission_count,
    jit_emission_time,
    jit_deform_count,
    jit_deform_time,
    stats_since,
    minmax_stats_since
   FROM pg_stat_statements(true) pg_stat_statements(userid, dbid, toplevel, queryid, query, plans, total_plan_time, min_plan_time, max_plan_time, mean_plan_time, stddev_plan_time, calls, total_exec_time, min_exec_time, max_exec_time, mean_exec_time, stddev_exec_time, rows, shared_blks_hit, shared_blks_read, shared_blks_dirtied, shared_blks_written, local_blks_hit, local_blks_read, local_blks_dirtied, local_blks_written, temp_blks_read, temp_blks_written, shared_blk_read_time, shared_blk_write_time, local_blk_read_time, local_blk_write_time, temp_blk_read_time, temp_blk_write_time, wal_records, wal_fpi, wal_bytes, jit_functions, jit_generation_time, jit_inlining_count, jit_inlining_time, jit_optimization_count, jit_optimization_time, jit_emission_count, jit_emission_time, jit_deform_count, jit_deform_time, stats_since, minmax_stats_since);"
pg_shadow,null
pg_roles,null
pg_hba_file_rules,null
pg_settings,null
pg_file_settings,null
pg_backend_memory_contexts,null
pg_ident_file_mappings,null
pg_config,null
pg_shmem_allocations,null
pg_tables,null
pg_statio_all_sequences,null
pg_replication_origin_status,null
pg_statio_sys_sequences,null
pg_statio_user_sequences,null
pg_group,null
pg_user,null
pg_policies,null
pg_rules,null
pg_views,null
pg_matviews,null
pg_indexes,null
pg_sequences,null
pg_stats,null
pg_stats_ext,null
pg_stats_ext_exprs,null
pg_publication_tables,null
pg_locks,null
pg_cursors,null
pg_available_extensions,null
pg_available_extension_versions,null
pg_prepared_xacts,null
pg_prepared_statements,null
pg_seclabels,null
pg_timezone_abbrevs,null
pg_timezone_names,null
pg_stat_all_tables,null
pg_stat_xact_all_tables,null
pg_stat_xact_user_tables,null
pg_stat_sys_tables,null
pg_stat_xact_sys_tables,null
pg_stat_user_tables,null
pg_statio_all_tables,null
pg_statio_sys_tables,null
pg_statio_user_tables,null
pg_stat_all_indexes,null
pg_stat_sys_indexes,null
pg_stat_user_indexes,null
pg_statio_all_indexes,null
pg_statio_sys_indexes,null
pg_statio_user_indexes,null
pg_stat_activity,null
pg_stat_replication,null
pg_stat_slru,null
pg_stat_wal_receiver,null
pg_stat_recovery_prefetch,null
pg_stat_subscription,null
pg_stat_ssl,null
pg_stat_gssapi,null
pg_replication_slots,null
pg_stat_replication_slots,null
pg_stat_database,null
pg_stat_database_conflicts,null
pg_stat_user_functions,null
pg_stat_xact_user_functions,null
pg_stat_archiver,null
pg_stat_bgwriter,null
pg_stat_checkpointer,null
pg_stat_io,null
pg_stat_wal,null
pg_stat_progress_analyze,null
pg_stat_progress_vacuum,null
pg_stat_progress_cluster,null
pg_stat_progress_create_index,null
pg_stat_progress_basebackup,null
pg_stat_progress_copy,null
pg_user_mappings,null
pg_stat_subscription_stats,null
pg_wait_events,null
column_column_usage,null
information_schema_catalog_name,null
check_constraints,null
applicable_roles,null
administrable_role_authorizations,null
attributes,null
collations,null
character_sets,null
check_constraint_routine_usage,null
column_privileges,null
collation_character_set_applicability,null
column_domain_usage,null
column_udt_usage,null
columns,null
constraint_column_usage,null
constraint_table_usage,null
domain_constraints,null
routine_table_usage,null
domain_udt_usage,null
domains,null
enabled_roles,null
routines,null
key_column_usage,null
parameters,null
referential_constraints,null
schemata,null
role_column_grants,null
routine_column_usage,null
routine_privileges,null
sequences,null
role_routine_grants,null
routine_routine_usage,null
routine_sequence_usage,null
role_table_grants,null
table_privileges,null
table_constraints,null
transforms,null
tables,null
triggered_update_columns,null
triggers,null
udt_privileges,null
_pg_foreign_data_wrappers,null
role_udt_grants,null
usage_privileges,null
foreign_tables,null
role_usage_grants,null
foreign_data_wrapper_options,null
user_defined_types,null
view_column_usage,null
view_routine_usage,null
foreign_data_wrappers,null
view_table_usage,null
views,null
_pg_foreign_servers,null
data_type_privileges,null
element_types,null
_pg_foreign_table_columns,null
_pg_user_mappings,null
column_options,null
foreign_server_options,null
foreign_servers,null
_pg_foreign_tables,null
foreign_table_options,null
user_mapping_options,null
user_mappings,null
decrypted_secrets,null


// TABLAS Y COLUMNAS 

table_name,column_name,data_type
investments,id,uuid
investments,user_id,uuid
investments,inversion_actual,numeric
investments,tasa_mensual,numeric
investments,ganancia_acumulada,numeric
investments,created_at,timestamp with time zone
investments,updated_at,timestamp with time zone
investments,last_week_generated,date
profiles,id,uuid
profiles,email,text
profiles,full_name,text
profiles,role,text
profiles,created_at,timestamp with time zone
profiles,updated_at,timestamp with time zone
weekly_earnings,id,uuid
weekly_earnings,user_id,uuid
weekly_earnings,investment_id,uuid
weekly_earnings,investment_amount,numeric
weekly_earnings,weekly_rate,numeric
weekly_earnings,earning_amount,numeric
weekly_earnings,week_start,date
weekly_earnings,week_end,date
weekly_earnings,created_at,timestamp with time zone
withdrawals,id,uuid
withdrawals,user_id,uuid
withdrawals,monto,numeric
withdrawals,estado,text
withdrawals,fecha_solicitud,timestamp with time zone
withdrawals,fecha_procesado,timestamp with time zone
withdrawals,created_at,timestamp with time zone