import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Klijent sa `service_role` ključem — ZAOBILAZI SVE RLS POLITIKE.
 *
 * Koristi ga isključivo za operacije koje po dizajnu moraju preći granicu
 * jednog korisnika (cron obračun, zatvaranje glasanja, slanje notifikacija).
 * Nikad ga ne koristi da bi "zaobišao" politiku koja smeta — to je znak da je
 * politika pogrešna.
 */
export function adminKlijent(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const kljuc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!url || !kljuc) {
    throw new Error('Nedostaje SUPABASE_URL ili SUPABASE_SERVICE_ROLE_KEY');
  }

  return createClient(url, kljuc, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Klijent koji nasljeđuje identitet pozivaoca iz `Authorization` zaglavlja.
 * RLS politike se primjenjuju normalno — ovo je podrazumijevani izbor.
 */
export function korisnickiKlijent(req: Request): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL')!;
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!;

  return createClient(url, anon, {
    global: {
      headers: { Authorization: req.headers.get('Authorization') ?? '' },
    },
    auth: { persistSession: false },
  });
}

export const corsZaglavlja = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function odgovor(tijelo: unknown, status = 200): Response {
  return new Response(JSON.stringify(tijelo), {
    status,
    headers: { ...corsZaglavlja, 'Content-Type': 'application/json' },
  });
}

export function greska(poruka: string, status = 400): Response {
  return odgovor({ greska: poruka }, status);
}

/**
 * Provjerava da poziv dolazi od Supabase cron-a / internog zadatka, a ne
 * spolja. Cron se konfiguriše da šalje `X-Cron-Kljuc` iz secrets-a.
 */
export function jeCronPoziv(req: Request): boolean {
  const ocekivan = Deno.env.get('CRON_KLJUC');
  if (!ocekivan) return false;
  return req.headers.get('X-Cron-Kljuc') === ocekivan;
}
