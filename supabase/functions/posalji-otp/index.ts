/**
 * Slanje OTP koda preko Vibera, sa padom na SMS.
 *
 * Zašto uopšte postoji: Supabase Auth podržava SMS OTP kroz svoje provajdere,
 * ali Viber je u regionu jeftiniji i ima bolju dostavu. Ova funkcija se
 * uključuje kao Auth Hook ("Send SMS Hook"), pa Supabase preko nje šalje kod
 * umjesto podrazumijevanim kanalom.
 *
 * ⚠️ SKELET — integracija sa konkretnim provajderom nije implementirana.
 * Prije produkcije: potpisati ugovor sa provajderom, staviti ključeve u
 * `supabase secrets set`, i implementirati `posaljiViber` / `posaljiSms`.
 */

import { corsZaglavlja, greska, odgovor } from '../_shared/supabase.ts';

interface AuthHookZahtjev {
  user: { phone?: string; email?: string };
  sms?: { otp: string };
}

async function posaljiViber(_telefon: string, _kod: string): Promise<boolean> {
  const url = Deno.env.get('OTP_PROVAJDER_URL');
  const kljuc = Deno.env.get('OTP_PROVAJDER_KLJUC');
  if (!url || !kljuc) return false;

  // TODO: stvarni poziv provajdera.
  // Vratiti `false` kod neuspjeha da bi se aktivirao pad na SMS.
  return false;
}

async function posaljiSms(_telefon: string, _kod: string): Promise<boolean> {
  // TODO: stvarni poziv SMS provajdera.
  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsZaglavlja });
  }

  try {
    const zahtjev: AuthHookZahtjev = await req.json();
    const telefon = zahtjev.user?.phone;
    const kod = zahtjev.sms?.otp;

    if (!telefon || !kod) {
      return greska('Nedostaje broj telefona ili kod');
    }

    // Viber prvo (jeftinije), SMS kao rezerva.
    const poslato = (await posaljiViber(telefon, kod)) ||
      (await posaljiSms(telefon, kod));

    if (!poslato) {
      // Namjerno ne otkrivamo detalje provajdera u odgovoru.
      console.error('Slanje OTP-a nije uspjelo za', telefon.slice(-4));
      return greska('Slanje koda trenutno nije moguće', 502);
    }

    return odgovor({ poslato: true });
  } catch (e) {
    console.error(e);
    return greska(e instanceof Error ? e.message : 'Nepoznata greška', 500);
  }
});
