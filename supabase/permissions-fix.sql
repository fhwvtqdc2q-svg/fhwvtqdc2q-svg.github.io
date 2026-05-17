-- Run this only if the app shows:
-- permission denied for table customer_requests

create table if not exists public.inventory_reports (
  id uuid primary key default gen_random_uuid(),
  report_date date not null default current_date,
  source text not null default 'ameen_excel' check (char_length(source) between 1 and 60),
  summary jsonb not null default '{}'::jsonb,
  items jsonb not null default '[]'::jsonb,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

grant usage on schema public to authenticated;
grant select, insert, update on table public.customer_requests to authenticated;
grant select, insert, delete on table public.inventory_reports to authenticated;

alter table public.customer_requests enable row level security;

drop policy if exists "staff can read customer requests" on public.customer_requests;
create policy "staff can read customer requests"
on public.customer_requests
for select
to authenticated
using (true);

drop policy if exists "staff can create customer requests" on public.customer_requests;
create policy "staff can create customer requests"
on public.customer_requests
for insert
to authenticated
with check (auth.uid() = created_by);

drop policy if exists "staff can update customer requests" on public.customer_requests;
create policy "staff can update customer requests"
on public.customer_requests
for update
to authenticated
using (true)
with check (true);

alter table public.inventory_reports enable row level security;

drop policy if exists "staff can read inventory reports" on public.inventory_reports;
create policy "staff can read inventory reports"
on public.inventory_reports
for select
to authenticated
using (true);

drop policy if exists "staff can create inventory reports" on public.inventory_reports;
create policy "staff can create inventory reports"
on public.inventory_reports
for insert
to authenticated
with check (auth.uid() = created_by);

drop policy if exists "staff can delete own inventory reports" on public.inventory_reports;
create policy "staff can delete own inventory reports"
on public.inventory_reports
for delete
to authenticated
using (auth.uid() = created_by);

create index if not exists inventory_reports_created_at_idx
on public.inventory_reports (created_at desc);

create index if not exists inventory_reports_report_date_idx
on public.inventory_reports (report_date desc);
