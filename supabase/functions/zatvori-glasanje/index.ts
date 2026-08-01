/**
 * Zatvaranje isteklih glasanja.
 *
 * Pokreće se po rasporedu (Supabase Scheduled Function, npr. svakih 15 minuta).
 * Sva logika prebrojavanja je u bazi — ova funkcija samo okida
 * `fn_obradi_istekla_glasanja()`, koja:
 *   1. prebacuje 'zakazano' → 'aktivno' kad nastupi početak,
 *   2. za svako isteklo 'aktivno' glasanje poziva `fn_zatvori_glasanje()`,
 *      koja prebrojava, snima snapshot rezultata i objavljuje odluku
 *      na oglasnoj tabli.
 *
 * Namjerno NE računa rezultat u TypeScript-u: prebrojavanje glasova mora
 * ostati na jednom mjestu, u bazi (vidi CLAUDE.md, sekcija 4.2).
 */

import {
  adminKlijent,
  corsZaglavlja,
  greska,
  jeCronPoziv,
  odgovor,
} from '../_shared/supabase.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsZaglavlja });
  }
  if (!jeCronPoziv(req)) {
    return greska('Neovlašten poziv', 401);
  }

  try {
    const db = adminKlijent();
    const { data, error } = await db.rpc('fn_obradi_istekla_glasanja');

    if (error) {
      console.error('Greška pri zatvaranju glasanja:', error);
      return greska(error.message, 500);
    }

    return odgovor({ zatvoreno: data ?? 0, vrijeme: new Date().toISOString() });
  } catch (e) {
    console.error(e);
    return greska(e instanceof Error ? e.message : 'Nepoznata greška', 500);
  }
});
