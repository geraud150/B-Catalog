const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const bucketName = 'catalog-photos';
const maxPhotoBytes = 5_000_000;

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function storageHeaders(contentType?: string) {
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
  const key = keys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!key) throw new Error('Photo storage is not configured.');
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    ...(contentType ? { 'Content-Type': contentType } : {}),
  };
}

async function ensurePrivateBucket() {
  const baseUrl = Deno.env.get('SUPABASE_URL');
  const headers = storageHeaders('application/json');
  const existing = await fetch(`${baseUrl}/storage/v1/bucket/${bucketName}`, {
    headers,
  });
  if (existing.ok) {
    const bucket = await existing.json();
    if (!bucket.public) return;
    const updated = await fetch(`${baseUrl}/storage/v1/bucket/${bucketName}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        id: bucketName,
        name: bucketName,
        public: false,
        file_size_limit: maxPhotoBytes,
        allowed_mime_types: ['image/jpeg'],
      }),
    });
    if (!updated.ok) throw new Error('Could not secure photo storage.');
    return;
  }
  if (existing.status !== 404) throw new Error('Could not access photo storage.');

  const created = await fetch(`${baseUrl}/storage/v1/bucket`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      id: bucketName,
      name: bucketName,
      public: false,
      file_size_limit: maxPhotoBytes,
      allowed_mime_types: ['image/jpeg'],
    }),
  });
  if (!created.ok && created.status !== 409) {
    throw new Error('Could not initialize photo storage.');
  }
}

async function uploadPhoto(body: any) {
  if (typeof body.productId !== 'string' ||
      !/^[0-9a-f-]{36}$/i.test(body.productId) ||
      typeof body.photoBase64 !== 'string' ||
      body.photoBase64.length > Math.ceil(maxPhotoBytes * 4 / 3) + 4) {
    return response(400, { error: 'invalid_photo' });
  }

  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(body.photoBase64), (value) => value.charCodeAt(0));
  } catch {
    return response(400, { error: 'invalid_photo' });
  }
  if (bytes.length === 0 || bytes.length > maxPhotoBytes) {
    return response(413, { error: 'photo_too_large' });
  }

  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const hash = Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, '0')
  ).join('');
  const objectPath = `products/${body.productId}/${hash}.jpg`;
  await ensurePrivateBucket();

  const uploaded = await fetch(
    `${Deno.env.get('SUPABASE_URL')}/storage/v1/object/${bucketName}/${objectPath}`,
    {
      method: 'POST',
      headers: {
        ...storageHeaders('image/jpeg'),
        'x-upsert': 'true',
      },
      body: bytes,
    },
  );
  if (!uploaded.ok) throw new Error('Photo upload failed.');
  return response(200, { photoObjectPath: objectPath });
}

/// The function has a service key for Storage, so the caller's JWT is also
/// checked against the caller-scoped catalogue query before that privilege is
/// used. A random authenticated user cannot turn this endpoint into storage.
async function assertCatalogAccess(request: Request) {
  const authorization = request.headers.get('authorization');
  const apikey = request.headers.get('apikey');
  if (!authorization || !apikey) return false;

  const response = await fetch(
    `${Deno.env.get('SUPABASE_URL')}/rest/v1/catalogs?select=id&limit=1`,
    { headers: { authorization, apikey } },
  );
  if (!response.ok) return false;
  const catalogs = await response.json();
  return Array.isArray(catalogs) && catalogs.length === 1;
}

async function downloadPhoto(body: any) {
  const path = typeof body.photoObjectPath === 'string' ? body.photoObjectPath : '';
  if (!/^products\/[0-9a-f-]{36}\/[0-9a-f]{64}\.jpg$/i.test(path)) {
    return response(400, { error: 'invalid_photo_path' });
  }

  const downloaded = await fetch(
    `${Deno.env.get('SUPABASE_URL')}/storage/v1/object/${bucketName}/${path}`,
    { headers: storageHeaders() },
  );
  if (!downloaded.ok) return response(404, { error: 'photo_not_found' });
  const bytes = new Uint8Array(await downloaded.arrayBuffer());
  if (bytes.length > maxPhotoBytes) return response(413, { error: 'photo_too_large' });

  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return response(200, { photoBase64: btoa(binary) });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return response(405, { error: 'method_not_allowed' });
  }

  try {
    if (!await assertCatalogAccess(request)) {
      return response(403, { error: 'catalog_access_required' });
    }
    const body = await request.json();
    if (body?.action === 'upload_photo') return await uploadPhoto(body);
    if (body?.action === 'download_photo') return await downloadPhoto(body);
    return response(400, { error: 'unknown_action' });
  } catch (error) {
    console.error('Photo storage request failed:', error);
    return response(500, { error: 'photo_storage_failed' });
  }
});
