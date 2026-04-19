-- ============================================================
-- PARCHE: Optimización de get_withdrawals_with_balances
-- ============================================================
-- 
-- PROBLEMA ACTUAL:
-- La función actual llama a get_available_balance_for_admin() 
-- POR CADA FILA de retiro. Esa función interna ejecuta 3 queries:
--   1. SUM(earning_amount) FROM daily_earnings
--   2. SUM(monto) FROM withdrawals WHERE estado = 'pagado'
--   3. SUM(monto) FROM withdrawals WHERE estado = 'pendiente'
--
-- Con 50 retiros = 150 queries. Con 250 retiros = 750 queries.
-- Esto se llama "problema N+1": 1 query principal + N sub-queries.
--
-- SOLUCIÓN:
-- Reemplazar con CTEs (Common Table Expressions) que pre-calculan
-- los totales UNA SOLA VEZ para todos los usuarios, y luego hacen
-- JOIN. Resultado: 4 queries totales sin importar cuántos retiros hay.
--
-- IMPACTO EN EL FRONTEND: NINGUNO
-- La función retorna exactamente las mismas columnas con los mismos 
-- nombres. El frontend (Withdrawals.jsx) no necesita cambios.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_withdrawals_with_balances()
RETURNS TABLE(
  withdrawal_id uuid,
  user_id uuid,
  user_name text,
  user_email text,
  monto numeric,
  estado text,
  fecha_solicitud timestamp with time zone,
  comentario_rechazo text,
  available_balance numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  WITH 
  -- CTE 1: Total de ganancias por usuario (1 sola query para TODOS)
  earnings_totals AS (
    SELECT 
      de.user_id,
      COALESCE(SUM(de.earning_amount), 0) AS total_earned
    FROM daily_earnings de
    GROUP BY de.user_id
  ),
  
  -- CTE 2: Total de retiros pagados por usuario (1 sola query para TODOS)
  paid_totals AS (
    SELECT 
      w2.user_id,
      COALESCE(SUM(w2.monto), 0) AS total_paid
    FROM withdrawals w2
    WHERE w2.estado = 'pagado'
    GROUP BY w2.user_id
  ),
  
  -- CTE 3: Total de retiros pendientes por usuario, 
  -- Y el monto de cada retiro individual pendiente para poder excluirlo
  pending_totals AS (
    SELECT
      w3.user_id,
      COALESCE(SUM(w3.monto), 0) AS total_pending
    FROM withdrawals w3
    WHERE w3.estado = 'pendiente'
    GROUP BY w3.user_id
  )
  
  -- Query principal: JOIN de todo
  SELECT
    w.id AS withdrawal_id,
    w.user_id,
    p.full_name AS user_name,
    p.email AS user_email,
    w.monto,
    w.estado,
    w.fecha_solicitud,
    w.comentario_rechazo,
    -- Balance = Ganado - Pagado - (Pendientes totales - este retiro si es pendiente)
    GREATEST(
      0,
      COALESCE(et.total_earned, 0) 
      - COALESCE(pt.total_paid, 0) 
      - COALESCE(pent.total_pending, 0) 
      + CASE WHEN w.estado = 'pendiente' THEN w.monto ELSE 0 END
    ) AS available_balance
  FROM withdrawals w
  INNER JOIN profiles p ON p.id = w.user_id
  LEFT JOIN earnings_totals et ON et.user_id = w.user_id
  LEFT JOIN paid_totals pt ON pt.user_id = w.user_id
  LEFT JOIN pending_totals pent ON pent.user_id = w.user_id
  ORDER BY w.fecha_solicitud DESC;
END;
$function$;
