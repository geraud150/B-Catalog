create function public.apply_catalog_product_deletion(
	p_product_id uuid,
	p_catalog_id uuid,
	p_expected_revision integer
)
returns setof public.products
language sql
security invoker
set search_path = ''
as $function$
	update public.products as product
	set is_deleted = true,
			updated_at = now(),
			revision = product.revision + 1
	where product.id = p_product_id
		and product.catalog_id = p_catalog_id
		and product.revision = p_expected_revision
	returning product.*;
$function$;

revoke all on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	from public, anon, authenticated;
grant execute on function public.apply_catalog_product_deletion(uuid, uuid, integer)
	to authenticated;
