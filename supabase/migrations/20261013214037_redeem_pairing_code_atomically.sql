create index pairing_codes_issued_by_idx
	on public.pairing_codes (issued_by);

create function public.redeem_pairing_code(
	p_code_hash text,
	p_token_hash text,
	p_device_name text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	device_id uuid;
	issuing_device uuid;
begin
	select id into device_id
	from public.paired_devices
	where token_hash = p_token_hash and revoked_at is null;

	if found then
		return device_id;
	end if;

	update public.pairing_codes
	set consumed_at = now()
	where code_hash = p_code_hash
		and consumed_at is null
		and expires_at > now()
	returning issued_by into issuing_device;

	if not found then
		return null;
	end if;

	insert into public.paired_devices (token_hash, device_name)
	values (p_token_hash, p_device_name)
	returning id into device_id;

	return device_id;
end;
$function$;

revoke all on function public.redeem_pairing_code(text, text, text)
	from public, anon, authenticated;
grant execute on function public.redeem_pairing_code(text, text, text)
	to service_role;
