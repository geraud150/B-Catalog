drop policy catalogs_select_owner on public.catalogs;
drop policy catalogs_insert_owner on public.catalogs;
drop policy catalogs_update_owner on public.catalogs;
drop policy products_select_catalog_owner on public.products;
drop policy products_insert_catalog_owner on public.products;
drop policy products_update_catalog_owner on public.products;

alter table public.catalogs drop constraint catalogs_owner_id_fkey;
alter table public.catalogs drop column owner_id;
alter table public.catalogs add column is_singleton boolean not null default true;
create unique index catalogs_singleton_idx on public.catalogs (is_singleton);

insert into public.catalogs (id, is_singleton)
values ('11111111-1111-4111-8111-111111111111', true)
on conflict (is_singleton) do nothing;

create table public.paired_devices (
	id uuid primary key default gen_random_uuid(),
	token_hash text not null unique,
	device_name text not null,
	created_at timestamptz not null default now(),
	revoked_at timestamptz
);

create table public.pairing_codes (
	code_hash text primary key,
	expires_at timestamptz not null,
	created_at timestamptz not null default now(),
	issued_by uuid not null references public.paired_devices (id) on delete cascade,
	consumed_at timestamptz
);

create table public.pairing_state (
	id smallint primary key check (id = 1),
	bootstrap_claimed boolean not null default false
);

insert into public.pairing_state (id) values (1);

alter table public.paired_devices enable row level security;
alter table public.pairing_codes enable row level security;
alter table public.pairing_state enable row level security;

revoke all on table public.catalogs, public.products,
	public.paired_devices, public.pairing_codes, public.pairing_state
	from public, anon, authenticated;
grant all on table public.catalogs, public.products,
	public.paired_devices, public.pairing_codes, public.pairing_state
	to service_role;

revoke all on function public.apply_catalog_product_change(jsonb, integer)
	from public, anon, authenticated;
grant execute on function public.apply_catalog_product_change(jsonb, integer)
	to service_role;

revoke all on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	from public, anon, authenticated;
grant execute on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	to service_role;

create function public.claim_initial_device(p_token_hash text, p_device_name text)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	device_id uuid;
begin
	update public.pairing_state
	set bootstrap_claimed = true
	where id = 1 and bootstrap_claimed = false;

	if not found then
		return null;
	end if;

	insert into public.paired_devices (token_hash, device_name)
	values (p_token_hash, p_device_name)
	returning id into device_id;

	return device_id;
end;
$function$;

revoke all on function public.claim_initial_device(text, text)
	from public, anon, authenticated;
grant execute on function public.claim_initial_device(text, text)
	to service_role;
