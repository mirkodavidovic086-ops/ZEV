/**
 * Mjesečni obračun naknade za održavanje.
 *
 * Pokreće se prvog u mjesecu (Scheduled Function) za sve aktivne zgrade, ili
 * ručno iz aplikacije za jednu zgradu.
 *
 * Obračun je u bazi (`fn_obracunaj_mjesec`) i idempotentan je — ponovno
 * pokretanje za isti period ne duplira zaduženja. Zato je bezbjedno da cron
 * "pretjera" i pokrene se više puta.
 */

import {
  adminKlijent,
  corsZaglavlja,
  greska,
  jeCronPoziv,
  korisnickiKlijent,
  odgovor,
} from '../_shared/supabase.ts';

interface Zahtjev {
  zgrada_id?: string;
  /** Prvi dan mjeseca, npr. "2026-08-01". Podrazumijevano tekući mjesec. */
  period?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsZaglavlja });
  }

  const tijelo: Zahtjev = await req.json().catch(() => ({}));
  const period = tijelo.period ??
    new Date().toISOString().slice(0, 7) + '-01';

  try {
    // Ručni poziv iz aplikacije: koristi identitet pozivaoca, pa
    // `fn_obracunaj_mjesec` sama provjeri da li je korisnik u upravi.
    if (tijelo.zgrada_id) {
      const db = korisnickiKlijent(req);
      const { data, error } = await db.rpc('fn_obracunaj_mjesec', {
        p_zgrada_id: tijelo.zgrada_id,
        p_period: period,
      });

      if (error) return greska(error.message, 403);
      return odgovor({ zgrada_id: tijelo.zgrada_id, period, izdato: data });
    }

    // Cron: obračun za sve aktivne zgrade.
    if (!jeCronPoziv(req)) {
      return greska('Neovlašten poziv', 401);
    }

    const db = adminKlijent();
    const { data: zgrade, error: gz } = await db
      .from('zgrade')
      .select('id, naziv')
      .eq('aktivna', true);

    if (gz) return greska(gz.message, 500);

    const rezultati: Array<{ zgrada: string; izdato: number | null; greska?: string }> = [];

    for (const z of zgrade ?? []) {
      const { data, error } = await db.rpc('fn_obracunaj_mjesec', {
        p_zgrada_id: z.id,
        p_period: period,
      });

      // Greška u jednoj zgradi ne smije zaustaviti obračun za ostale.
      rezultati.push({
        zgrada: z.naziv,
        izdato: data ?? null,
        ...(error ? { greska: error.message } : {}),
      });
    }

    return odgovor({ period, zgrada: rezultati.length, rezultati });
  } catch (e) {
    console.error(e);
    return greska(e instanceof Error ? e.message : 'Nepoznata greška', 500);
  }
});
