-- =========================================================
-- Configuration Supabase — Registre Réservations ASBL
-- Synchronisation temps réel + équipes + rôles + journal
-- A exécuter dans l'éditeur SQL de Supabase (SQL Editor)
-- =========================================================

create extension if not exists "pgcrypto";

-- 1. Table des équipes
-- Chaque équipe possède un code de modification et un code de consultation seule
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  edit_code text not null unique,
  view_code text not null unique,
  created_by text,
  created_at timestamptz not null default now()
);

-- 2. Table des données synchronisées
-- Une seule ligne par équipe : la totalité du registre (tableau JSON), remplacée à chaque modification
create table if not exists public.team_data (
  team_id uuid primary key references public.teams(id) on delete cascade,
  data jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text
);

create or replace function public.set_team_data_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_team_data_updated_at on public.team_data;
create trigger trg_team_data_updated_at
  before update on public.team_data
  for each row
  execute function public.set_team_data_updated_at();

-- 3. Journal d'activité (les 15 dernières actions sont affichées côté application)
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  author_name text not null,
  description text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_activity_log_team_id on public.activity_log (team_id, created_at desc);

-- 4. Row Level Security
-- Application "circuit fermé" : pas de compte individuel par personne, la protection
-- repose sur la connaissance du code d'équipe (comme indiqué dans le guide de déploiement).
-- On autorise donc l'accès anonyme (anon) à ces 3 tables, restreint au strict nécessaire.

alter table public.teams enable row level security;
alter table public.team_data enable row level security;
alter table public.activity_log enable row level security;

-- Teams : lecture nécessaire pour vérifier un code, écriture nécessaire pour créer une équipe
drop policy if exists "teams_select_anon" on public.teams;
create policy "teams_select_anon" on public.teams for select to anon using (true);

drop policy if exists "teams_insert_anon" on public.teams;
create policy "teams_insert_anon" on public.teams for insert to anon with check (true);

-- Team data : lecture/écriture ouvertes (protégées par la connaissance du code d'équipe côté appli)
drop policy if exists "team_data_select_anon" on public.team_data;
create policy "team_data_select_anon" on public.team_data for select to anon using (true);

drop policy if exists "team_data_insert_anon" on public.team_data;
create policy "team_data_insert_anon" on public.team_data for insert to anon with check (true);

drop policy if exists "team_data_update_anon" on public.team_data;
create policy "team_data_update_anon" on public.team_data for update to anon using (true) with check (true);

-- Activity log : lecture/écriture ouvertes
drop policy if exists "activity_log_select_anon" on public.activity_log;
create policy "activity_log_select_anon" on public.activity_log for select to anon using (true);

drop policy if exists "activity_log_insert_anon" on public.activity_log;
create policy "activity_log_insert_anon" on public.activity_log for insert to anon with check (true);

-- 5. Activation de la synchronisation temps réel (Realtime) sur team_data et activity_log
alter publication supabase_realtime add table public.team_data;
alter publication supabase_realtime add table public.activity_log;

-- =========================================================
-- Fin du script. Les tables sont prêtes pour la synchronisation.
-- =========================================================
