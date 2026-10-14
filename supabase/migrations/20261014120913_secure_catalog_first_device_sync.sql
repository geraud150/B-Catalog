-- Le catalogue est partagé par le compte interne de la boutique. Le premier
-- compte authentifié le revendique une seule fois ; les appareils utilisent
-- ensuite ce même compte.
alter table public.catalogs
	add column owner_id uuid references auth.users (id) on delete restrict,
	add column initializing_device_id uuid,
	add column initialization_started_at timestamptz;

drop policy if exists catalogs_anon_select on public.catalogs;
drop policy if exists catalogs_anon_update on public.catalogs;
drop policy if exists products_anon_select on public.products;
drop policy if exists products_anon_insert on public.products;
drop policy if exists products_anon_update on public.products;

revoke all on table public.catalogs, public.products from anon;
revoke all on function public.apply_catalog_product_change(jsonb, integer)
	from anon;
revoke all on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	from anon;

grant select, update on table public.catalogs to authenticated;
grant select, insert, update on table public.products to authenticated;
grant execute on function public.apply_catalog_product_change(jsonb, integer)
	to authenticated;
grant execute on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	to authenticated;

create policy catalogs_select_owner_or_unclaimed
	on public.catalogs for select to authenticated
	using (owner_id is null or (select auth.uid()) = owner_id);

create policy catalogs_claim_or_update_owner
	on public.catalogs for update to authenticated
	using (owner_id is null or (select auth.uid()) = owner_id)
	with check ((select auth.uid()) = owner_id);

create policy products_select_catalog_owner
	on public.products for select to authenticated
	using (
		exists (
			select 1 from public.catalogs c
			where c.id = products.catalog_id
				and c.owner_id = (select auth.uid())
		)
	);

create policy products_insert_catalog_owner
	on public.products for insert to authenticated
	with check (
		exists (
			select 1 from public.catalogs c
			where c.id = products.catalog_id
				and c.owner_id = (select auth.uid())
		)
	);

create policy products_update_catalog_owner
	on public.products for update to authenticated
	using (
		exists (
			select 1 from public.catalogs c
			where c.id = products.catalog_id
				and c.owner_id = (select auth.uid())
		)
	)
	with check (
		exists (
			select 1 from public.catalogs c
			where c.id = products.catalog_id
				and c.owner_id = (select auth.uid())
		)
	);

-- Une revendication est une location de quinze minutes. Elle évite qu'un
-- second appareil envoie son catalogue tant que le gagnant n'a pas terminé.
create function public.claim_catalog_initialization(
	p_catalog_id uuid,
	p_device_id uuid
)
returns table (state text)
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	catalog public.catalogs;
begin
	update public.catalogs
	set owner_id = (select auth.uid())
	where id = p_catalog_id
		and owner_id is null;

	select * into catalog
	from public.catalogs
	where id = p_catalog_id
	for update;

	if not found then
		return;
	end if;

	if catalog.initialized_at is not null then
		return query select 'ready'::text;
		return;
	end if;

	if catalog.initializing_device_id = p_device_id then
		return query select 'winner'::text;
		return;
	end if;

	if catalog.initializing_device_id is null
		or catalog.initialization_started_at < now() - interval '15 minutes' then
		update public.catalogs
		set initializing_device_id = p_device_id,
			initialization_started_at = now()
		where id = p_catalog_id;
		return query select 'winner'::text;
		return;
	end if;

	return query select 'waiting'::text;
end;
$function$;

create function public.complete_catalog_initialization(
	p_catalog_id uuid,
	p_device_id uuid
)
returns boolean
language sql
security invoker
set search_path = ''
as $function$
	update public.catalogs
	set initialized_at = coalesce(initialized_at, now()),
		initializing_device_id = null,
		initialization_started_at = null
	where id = p_catalog_id
		and initializing_device_id = p_device_id
		and initialized_at is null
	returning true;
$function$;

revoke all on function public.claim_catalog_initialization(uuid, uuid)
	from public, anon, authenticated;
revoke all on function public.complete_catalog_initialization(uuid, uuid)
	from public, anon, authenticated;
grant execute on function public.claim_catalog_initialization(uuid, uuid)
	to authenticated;
grant execute on function public.complete_catalog_initialization(uuid, uuid)
	to authenticated;
