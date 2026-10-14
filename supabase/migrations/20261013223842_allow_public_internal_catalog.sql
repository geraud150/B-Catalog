drop function public.claim_initial_device(text, text);
drop function public.redeem_pairing_code(text, text, text);
drop table public.pairing_codes;
drop table public.pairing_state;
drop table public.paired_devices;

revoke all on table public.catalogs, public.products from public, authenticated;
revoke all on table public.catalogs, public.products from anon;
grant select, update on table public.catalogs to anon;
grant select, insert, update on table public.products to anon;

create policy catalogs_anon_select
	on public.catalogs for select to anon
	using (true);

create policy catalogs_anon_update
	on public.catalogs for update to anon
	using (true)
	with check (true);

create policy products_anon_select
	on public.products for select to anon
	using (true);

create policy products_anon_insert
	on public.products for insert to anon
	with check (true);

create policy products_anon_update
	on public.products for update to anon
	using (true)
	with check (true);

grant execute on function public.apply_catalog_product_change(jsonb, integer)
	to anon;
grant execute on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	to anon;
