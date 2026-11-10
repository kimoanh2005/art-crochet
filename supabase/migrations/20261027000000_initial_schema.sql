create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.charts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  category text not null,
  description text not null default '',
  rows_count integer not null check (rows_count between 2 and 50),
  cols_count integer not null check (cols_count between 2 and 50),
  thumbnail_url text,
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stitch_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  symbol text not null,
  description text not null default '',
  sort_order integer not null default 0
);

create table if not exists public.chart_colors (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  color_name text not null,
  hex_code text not null check (hex_code ~ '^#[0-9A-Fa-f]{6}$'),
  yarn_brand text,
  yarn_code text,
  created_at timestamptz not null default now(),
  unique (chart_id, id)
);

create table if not exists public.chart_cells (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  row_index integer not null check (row_index >= 0),
  col_index integer not null check (col_index >= 0),
  stitch_type_id uuid references public.stitch_types(id),
  chart_color_id uuid references public.chart_colors(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chart_id, row_index, col_index)
);

create table if not exists public.chart_progress (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  completed_rows integer not null default 0 check (completed_rows >= 0),
  current_row integer not null default 1 check (current_row >= 1),
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'completed')),
  notes text not null default '',
  updated_at timestamptz not null default now(),
  unique (chart_id, user_id)
);

create table if not exists public.chart_exports (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  file_type text not null check (file_type in ('png', 'pdf')),
  file_url text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.yarn_colors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  hex_code text not null check (hex_code ~ '^#[0-9A-Fa-f]{6}$'),
  brand text not null default '',
  yarn_code text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists charts_user_updated_idx
  on public.charts(user_id, updated_at desc);
create index if not exists chart_cells_chart_idx on public.chart_cells(chart_id);
create index if not exists chart_colors_chart_idx on public.chart_colors(chart_id);

insert into public.stitch_types (code, name, symbol, description, sort_order)
values
  ('CH', 'Mũi bính', '○', 'Chain stitch', 1),
  ('SC', 'Mũi đơn', '×', 'Single crochet', 2),
  ('HDC', 'Mũi nửa kép', 'T', 'Half double crochet', 3),
  ('DC', 'Mũi kép', 'T̸', 'Double crochet', 4),
  ('SLST', 'Mũi trượt', '•', 'Slip stitch', 5)
on conflict (code) do nothing;

insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'display_name', split_part(u.email, '@', 1))
from auth.users u
on conflict (id) do nothing;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_profile_after_signup on auth.users;
create trigger create_profile_after_signup
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

create or replace function public.save_chart_design(
  p_chart_id uuid,
  p_colors jsonb,
  p_cells jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.charts
    where id = p_chart_id and user_id = auth.uid()
  ) then
    raise exception 'Chart not found or access denied';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_cells, '[]'::jsonb)) as item
    join public.charts chart on chart.id = p_chart_id
    where (item ->> 'row_index')::integer < 0
      or (item ->> 'row_index')::integer >= chart.rows_count
      or (item ->> 'col_index')::integer < 0
      or (item ->> 'col_index')::integer >= chart.cols_count
      or not exists (
        select 1 from public.stitch_types stitch
        where stitch.code = item ->> 'stitch_code'
      )
  ) then
    raise exception 'Chart cell data is invalid';
  end if;

  delete from public.chart_cells where chart_id = p_chart_id;
  delete from public.chart_colors where chart_id = p_chart_id;

  insert into public.chart_colors (id, chart_id, color_name, hex_code, yarn_brand, yarn_code)
  select
    (item ->> 'id')::uuid,
    p_chart_id,
    item ->> 'color_name',
    item ->> 'hex_code',
    nullif(item ->> 'yarn_brand', ''),
    nullif(item ->> 'yarn_code', '')
  from jsonb_array_elements(coalesce(p_colors, '[]'::jsonb)) as item;

  insert into public.chart_cells (
    chart_id, row_index, col_index, stitch_type_id, chart_color_id
  )
  select
    p_chart_id,
    (item ->> 'row_index')::integer,
    (item ->> 'col_index')::integer,
    stitch.id,
    color.id
  from jsonb_array_elements(coalesce(p_cells, '[]'::jsonb)) as item
  join public.stitch_types stitch on stitch.code = item ->> 'stitch_code'
  left join public.chart_colors color
    on color.chart_id = p_chart_id and color.hex_code = item ->> 'hex_code';

  update public.charts set updated_at = now() where id = p_chart_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.charts enable row level security;
alter table public.stitch_types enable row level security;
alter table public.chart_colors enable row level security;
alter table public.chart_cells enable row level security;
alter table public.chart_progress enable row level security;
alter table public.chart_exports enable row level security;
alter table public.yarn_colors enable row level security;

grant select, insert, update, delete on public.profiles, public.charts,
  public.chart_colors, public.chart_cells, public.chart_progress,
  public.chart_exports, public.yarn_colors to authenticated;
grant select on public.stitch_types to authenticated;

create policy "Profiles are private to their owner"
  on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy "Users manage their own charts"
  on public.charts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Authenticated users can read stitch types"
  on public.stitch_types for select to authenticated using (true);

create policy "Users manage colors of their charts"
  on public.chart_colors for all to authenticated
  using (exists (
    select 1 from public.charts c
    where c.id = chart_id and c.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.charts c
    where c.id = chart_id and c.user_id = auth.uid()
  ));

create policy "Users manage cells of their charts"
  on public.chart_cells for all to authenticated
  using (exists (
    select 1 from public.charts c
    where c.id = chart_id and c.user_id = auth.uid()
  ))
  with check (
    exists (
      select 1 from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
    and (chart_color_id is null or exists (
      select 1 from public.chart_colors cc
      where cc.id = chart_color_id and cc.chart_id = chart_id
    ))
  );

create policy "Users manage their own chart progress"
  on public.chart_progress for all to authenticated
  using (
    user_id = auth.uid() and exists (
      select 1 from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid() and exists (
      select 1 from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  );

create policy "Users manage their own chart exports"
  on public.chart_exports for all to authenticated
  using (
    user_id = auth.uid() and exists (
      select 1 from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid() and exists (
      select 1 from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  );

create policy "Users manage their own yarn colors"
  on public.yarn_colors for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on function public.save_chart_design(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.save_chart_design(uuid, jsonb, jsonb) to authenticated;
