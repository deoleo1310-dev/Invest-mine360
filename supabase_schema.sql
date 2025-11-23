-- --------------------------------------------------------
-- COPIA Y PEGA ESTO EN EL SQL EDITOR DE SUPABASE
-- --------------------------------------------------------

-- 1. Crear tabla de Perfiles (Usuarios)
create table public.profiles (
  id uuid not null references auth.users on delete cascade,
  email text not null,
  full_name text,
  role text default 'cliente' check (role in ('admin', 'cliente')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (id)
);

-- 2. Crear tabla de Inversiones
create table public.investments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  inversion_actual numeric default 0,
  tasa_mensual numeric default 0,
  ganancia_acumulada numeric default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Crear tabla de Retiros
create table public.withdrawals (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  monto numeric not null,
  estado text default 'pendiente' check (estado in ('pendiente', 'pagado', 'rechazado')),
  fecha_solicitud timestamptz default now(),
  fecha_procesado timestamptz,
  created_at timestamptz default now()
);

-- 4. Habilitar Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.investments enable row level security;
alter table public.withdrawals enable row level security;

-- 5. Políticas de Seguridad (Policies)

-- PROFILES
-- Admin ve todo, Usuario ve su propio perfil
create policy "Admin ve todos los perfiles" on public.profiles
  for select using (auth.uid() in (select id from public.profiles where role = 'admin'));

create policy "Usuarios ven su propio perfil" on public.profiles
  for select using (auth.uid() = id);

create policy "Admin puede insertar perfiles" on public.profiles
  for insert with check (true); -- Permitimos insertar para simplificar el flujo de creación

create policy "Admin puede actualizar perfiles" on public.profiles
  for update using (auth.uid() in (select id from public.profiles where role = 'admin'));

-- INVESTMENTS
create policy "Admin gestiona inversiones" on public.investments
  for all using (auth.uid() in (select id from public.profiles where role = 'admin'));

create policy "Usuarios ven su inversion" on public.investments
  for select using (auth.uid() = user_id);

-- WITHDRAWALS
create policy "Admin gestiona retiros" on public.withdrawals
  for all using (auth.uid() in (select id from public.profiles where role = 'admin'));

create policy "Usuarios ven sus retiros" on public.withdrawals
  for select using (auth.uid() = user_id);

create policy "Usuarios pueden solicitar retiros" on public.withdrawals
  for insert with check (auth.uid() = user_id);

-- 6. Trigger para crear perfil automáticamente al registrarse (Opcional pero recomendado)
-- Nota: En este sistema el Admin crea usuarios manualmente, pero esto ayuda si usas el registro público.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', coalesce(new.raw_user_meta_data->>'role', 'cliente'));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 7. Insertar un ADMIN inicial (IMPORTANTE: Crea el usuario en Auth primero manualmente o usa este hack si tienes acceso directo a la DB, 
-- pero lo mejor es registrarte en la app y luego cambiar tu rol a 'admin' en la tabla profiles manualmente desde el dashboard de Supabase).
