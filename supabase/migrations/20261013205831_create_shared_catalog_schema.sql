create table public.catalogs (
	id uuid primary key default gen_random_uuid(),
	owner_id uuid not null unique references auth.users (id) on delete cascade,
	initialized_at timestamptz,
	created_at timestamptz not null default now()
);

create table public.products (
	id uuid primary key,
	catalog_id uuid not null references public.catalogs (id) on delete cascade,
	barcode text,
	sku text,
	name text not null,
	category text,
	description text,
	cost_price numeric,
	sell_price numeric,
	quantity integer not null default 0,
	photo_object_path text,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	synced_to_loyverse boolean not null default false,
	option_name text,
	option_value text,
	loyverse_item_id text,
	loyverse_variant_id text,
	group_id text,
	import_source text,
	import_batch_id text,
	revision integer not null default 1 check (revision > 0),
	is_deleted boolean not null default false
);

create index products_catalog_updated_idx
	on public.products (catalog_id, updated_at desc);

alter table public.catalogs enable row level security;
alter table public.products enable row level security;

revoke all on table public.catalogs, public.products from anon, authenticated;
grant select, insert, update on table public.catalogs to authenticated;
grant select, insert, update on table public.products to authenticated;

create policy catalogs_select_owner
	on public.catalogs for select to authenticated
	using ((select auth.uid()) = owner_id);

create policy catalogs_insert_owner
	on public.catalogs for insert to authenticated
	with check ((select auth.uid()) = owner_id);

create policy catalogs_update_owner
	on public.catalogs for update to authenticated
	using ((select auth.uid()) = owner_id)
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

create function public.apply_catalog_product_change(
	p_payload jsonb,
	p_expected_revision integer
)
returns setof public.products
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	changed public.products;
begin
	insert into public.products as existing (
		id, catalog_id, barcode, sku, name, category, description,
		cost_price, sell_price, quantity, photo_object_path, created_at,
		updated_at, synced_to_loyverse, option_name, option_value,
		loyverse_item_id, loyverse_variant_id, group_id, import_source,
		import_batch_id, is_deleted
	) values (
		(p_payload ->> 'id')::uuid,
		(p_payload ->> 'catalog_id')::uuid,
		p_payload ->> 'barcode',
		p_payload ->> 'sku',
		p_payload ->> 'name',
		p_payload ->> 'category',
		p_payload ->> 'description',
		(p_payload ->> 'cost_price')::numeric,
		(p_payload ->> 'sell_price')::numeric,
		coalesce((p_payload ->> 'quantity')::integer, 0),
		p_payload ->> 'photo_object_path',
		coalesce((p_payload ->> 'created_at')::timestamptz, now()),
		now(),
		coalesce((p_payload ->> 'synced_to_loyverse')::boolean, false),
		p_payload ->> 'option_name',
		p_payload ->> 'option_value',
		p_payload ->> 'loyverse_item_id',
		p_payload ->> 'loyverse_variant_id',
		p_payload ->> 'group_id',
		p_payload ->> 'import_source',
		p_payload ->> 'import_batch_id',
		coalesce((p_payload ->> 'is_deleted')::boolean, false)
	)
	on conflict (id) do update set
		barcode = excluded.barcode,
		sku = excluded.sku,
		name = excluded.name,
		category = excluded.category,
		description = excluded.description,
		cost_price = excluded.cost_price,
		sell_price = excluded.sell_price,
		quantity = excluded.quantity,
		photo_object_path = excluded.photo_object_path,
		updated_at = now(),
		synced_to_loyverse = excluded.synced_to_loyverse,
		option_name = excluded.option_name,
		option_value = excluded.option_value,
		loyverse_item_id = excluded.loyverse_item_id,
		loyverse_variant_id = excluded.loyverse_variant_id,
		group_id = excluded.group_id,
		import_source = excluded.import_source,
		import_batch_id = excluded.import_batch_id,
		revision = existing.revision + 1,
		is_deleted = excluded.is_deleted
	where existing.catalog_id = excluded.catalog_id
		and existing.revision = p_expected_revision
	returning existing.* into changed;

	if not found then
		return;
	end if;

	return next changed;
end;
$function$;

revoke all on function public.apply_catalog_product_change(jsonb, integer)
	from public, anon, authenticated;
grant execute on function public.apply_catalog_product_change(jsonb, integer)
	to authenticated;
