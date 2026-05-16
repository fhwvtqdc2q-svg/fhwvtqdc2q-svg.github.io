-- Run this only if the app shows:
-- permission denied for table customer_requests

grant usage on schema public to authenticated;
grant select, insert, update on table public.customer_requests to authenticated;

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
