alter table public.charts
  add column if not exists chart_type text not null default 'pixel';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.charts'::regclass
      and conname = 'charts_chart_type_check'
  ) then
    alter table public.charts
      add constraint charts_chart_type_check
      check (chart_type in ('pixel', 'stitch_symbols', 'circular'));
  end if;
end;
$$;

create table if not exists public.chart_sections (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  section_index integer not null check (section_index >= 0),
  instruction_text text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chart_id, section_index)
);

create table if not exists public.chart_stitches (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  section_index integer not null check (section_index >= 0),
  sequence_index integer not null check (sequence_index >= 0),
  position_x double precision not null check (position_x between 0 and 1),
  position_y double precision not null check (position_y between 0 and 1),
  stitch_type_id uuid not null references public.stitch_types(id),
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists chart_sections_chart_idx
  on public.chart_sections(chart_id, section_index);
create index if not exists chart_stitches_chart_section_idx
  on public.chart_stitches(chart_id, section_index, sequence_index);

create or replace function public.validate_chart_section_bounds()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_chart_type text;
  v_rows_count integer;
begin
  select chart_type, rows_count
    into v_chart_type, v_rows_count
    from public.charts
    where id = new.chart_id;

  if not found then
    raise exception 'Chart not found';
  end if;

  if v_chart_type not in ('stitch_symbols', 'circular') then
    raise exception 'Sections and freeform stitches require a symbol or circular chart';
  end if;

  if new.section_index >= v_rows_count then
    raise exception 'Section index is outside the chart bounds';
  end if;

  return new;
end;
$$;

create trigger validate_chart_stitch_section_bounds
  before insert or update of chart_id, section_index
  on public.chart_stitches
  for each row execute function public.validate_chart_section_bounds();

create trigger validate_chart_section_bounds
  before insert or update of chart_id, section_index
  on public.chart_sections
  for each row execute function public.validate_chart_section_bounds();

alter table public.chart_sections enable row level security;
alter table public.chart_stitches enable row level security;

grant select, insert, update, delete
  on public.chart_sections, public.chart_stitches to authenticated;

create policy "Users manage sections of their charts"
  on public.chart_sections for all to authenticated
  using (
    exists (
      select 1
      from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  );

create policy "Users manage stitches of their charts"
  on public.chart_stitches for all to authenticated
  using (
    exists (
      select 1
      from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.charts c
      where c.id = chart_id and c.user_id = auth.uid()
    )
  );

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
declare
  v_chart public.charts%rowtype;
begin
  select *
    into v_chart
    from public.charts
    where id = p_chart_id and user_id = auth.uid();

  if not found then
    raise exception 'Chart not found or access denied';
  end if;

  if v_chart.chart_type <> 'pixel' then
    raise exception 'Pixel cells can only be saved to a Pixel chart';
  end if;

  if jsonb_typeof(coalesce(p_colors, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_cells, '[]'::jsonb)) <> 'array' then
    raise exception 'Colors and cells must be JSON arrays';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_cells, '[]'::jsonb)) as entries(item)
    where jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'row_index', '') !~ '^[0-9]+$'
       or coalesce(item ->> 'col_index', '') !~ '^[0-9]+$'
       or coalesce(item ->> 'hex_code', '') !~ '^#[0-9A-Fa-f]{6}$'
  ) then
    raise exception 'Chart cell data is invalid';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_cells, '[]'::jsonb)) as entries(item)
    where (item ->> 'row_index')::integer >= v_chart.rows_count
       or (item ->> 'col_index')::integer >= v_chart.cols_count
       or (
         coalesce(item ->> 'stitch_code', '') <> ''
         and not exists (
         select 1
         from public.stitch_types st
         where st.code = item ->> 'stitch_code'
         )
       )
  ) then
    raise exception 'Chart cell data is outside the chart bounds or uses an unknown stitch type';
  end if;

  delete from public.chart_cells where chart_id = p_chart_id;
  delete from public.chart_colors where chart_id = p_chart_id;

  insert into public.chart_colors (
    id, chart_id, color_name, hex_code, yarn_brand, yarn_code
  )
  select
    (item ->> 'id')::uuid,
    p_chart_id,
    item ->> 'color_name',
    item ->> 'hex_code',
    nullif(item ->> 'yarn_brand', ''),
    nullif(item ->> 'yarn_code', '')
  from jsonb_array_elements(coalesce(p_colors, '[]'::jsonb)) as entries(item);

  insert into public.chart_cells (
    chart_id, row_index, col_index, stitch_type_id, chart_color_id
  )
  select
    p_chart_id,
    (item ->> 'row_index')::integer,
    (item ->> 'col_index')::integer,
    st.id,
    color.id
  from jsonb_array_elements(coalesce(p_cells, '[]'::jsonb)) as entries(item)
  left join public.stitch_types st on st.code = item ->> 'stitch_code'
  left join public.chart_colors color
    on color.chart_id = p_chart_id and color.hex_code = item ->> 'hex_code';

  update public.charts set updated_at = now() where id = p_chart_id;
end;
$$;

create or replace function public.save_chart_stitches(
  p_chart_id uuid,
  p_stitches jsonb,
  p_sections jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_chart public.charts%rowtype;
begin
  select *
    into v_chart
    from public.charts
    where id = p_chart_id and user_id = auth.uid();

  if not found then
    raise exception 'Chart not found or access denied';
  end if;

  if v_chart.chart_type not in ('stitch_symbols', 'circular') then
    raise exception 'Freeform stitches can only be saved to symbol or circular charts';
  end if;

  if jsonb_typeof(coalesce(p_stitches, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_sections, '[]'::jsonb)) <> 'array' then
    raise exception 'Stitches and sections must be JSON arrays';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_stitches, '[]'::jsonb)) as entries(item)
    where jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'section_index', '') !~ '^[0-9]+$'
       or coalesce(item ->> 'sequence_index', '') !~ '^[0-9]+$'
       or coalesce(item ->> 'position_x', '') !~ '^[0-9]+([.][0-9]+)?$'
       or coalesce(item ->> 'position_y', '') !~ '^[0-9]+([.][0-9]+)?$'
       or coalesce(item ->> 'stitch_code', '') = ''
       or coalesce(item ->> 'color_hex', '') !~ '^#[0-9A-Fa-f]{6}$'
  ) then
    raise exception 'Chart stitch data is invalid';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_stitches, '[]'::jsonb)) as entries(item)
    where (item ->> 'section_index')::integer >= v_chart.rows_count
       or (item ->> 'position_x')::double precision not between 0 and 1
       or (item ->> 'position_y')::double precision not between 0 and 1
       or not exists (
         select 1
         from public.stitch_types st
         where st.code = item ->> 'stitch_code'
       )
  ) then
    raise exception 'Chart stitch data is outside the chart bounds or uses an unknown stitch type';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_sections, '[]'::jsonb)) as entries(item)
    where jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'section_index', '') !~ '^[0-9]+$'
  ) then
    raise exception 'Chart section data is invalid';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_sections, '[]'::jsonb)) as entries(item)
    where (item ->> 'section_index')::integer >= v_chart.rows_count
  ) then
    raise exception 'Chart section index is outside the chart bounds';
  end if;

  delete from public.chart_stitches where chart_id = p_chart_id;
  delete from public.chart_sections where chart_id = p_chart_id;

  insert into public.chart_stitches (
    chart_id,
    section_index,
    sequence_index,
    position_x,
    position_y,
    stitch_type_id,
    color_hex
  )
  select
    p_chart_id,
    (item ->> 'section_index')::integer,
    (item ->> 'sequence_index')::integer,
    (item ->> 'position_x')::double precision,
    (item ->> 'position_y')::double precision,
    st.id,
    item ->> 'color_hex'
  from jsonb_array_elements(coalesce(p_stitches, '[]'::jsonb)) as entries(item)
  join public.stitch_types st on st.code = item ->> 'stitch_code';

  insert into public.chart_sections (
    chart_id,
    section_index,
    instruction_text
  )
  select
    p_chart_id,
    (item ->> 'section_index')::integer,
    coalesce(item ->> 'instruction_text', '')
  from jsonb_array_elements(coalesce(p_sections, '[]'::jsonb)) as entries(item);

  update public.charts
    set updated_at = now()
    where id = p_chart_id;
end;
$$;

revoke all on function public.save_chart_stitches(uuid, jsonb, jsonb)
  from public, anon;
grant execute on function public.save_chart_stitches(uuid, jsonb, jsonb)
  to authenticated;

revoke all on function public.save_chart_design(uuid, jsonb, jsonb)
  from public, anon;
grant execute on function public.save_chart_design(uuid, jsonb, jsonb)
  to authenticated;
