-- Migration: Create program_progress table
-- Purpose: Journey state persisted server-side (survives reinstall)
-- Ref: docs/02-data-model-and-api.md §1.4; docs/migration-plan-v0.2.md §08

create table public.program_progress (
  user_id uuid primary key references public.app_user(id),
  current_week integer not null default 1,
  completed_steps jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),

  constraint program_progress_week_check check (current_week between 1 and 6)
);

comment on table public.program_progress is
  'Journey state. Server-side because it is a named data category and must survive reinstall.
   @omit';
comment on column public.program_progress.current_week is
  'Position in the six-week core program (1-6). One integer cannot gate several programs.';
comment on column public.program_progress.completed_steps is
  'Step completion map. Front end writes "<slug>:<n>" keys.';

create or replace function public.touch_program_progress()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger program_progress_touch_updated_at
  before update on public.program_progress
  for each row execute function public.touch_program_progress();
