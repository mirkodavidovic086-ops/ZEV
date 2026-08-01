/**
 * Vraća podatke uplatnice spremne za prikaz/štampu.
 *
 * QR payload NE sastavlja ova funkcija — generiše ga baza
 * (`transakcije_uplatnice.qr_sadrzaj`, kroz `fn_generisi_qr`), jer format
 * zavisi od standarda banke i konfiguriše se po zgradi (`zgrade.qr_standard`).
 * Ovdje se samo dohvata i pakuje.
 *
 * Poziv ide sa identitetom korisnika, pa RLS garantuje da stanar može dobiti
 * uplatnicu samo za SVOJ prostor.
 *
 * TODO: generisanje PDF-a (trenutno vraća JSON koji klijent iscrtava).
 */

import {
  corsZaglavlja,
  greska,
  korisnickiKlijent,
  odgovor,
} from '../_shared/supabase.ts';

interface Zahtjev {
  transakcija_id: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsZaglavlja });
  }

  const { transakcija_id }: Zahtjev = await req.json().catch(() => ({}));
  if (!transakcija_id) {
    return greska('Nedostaje transakcija_id');
  }

  try {
    const db = korisnickiKlijent(req);

    const { data, error } = await db
      .from('transakcije_uplatnice')
      .select(`
        id, iznos, valuta, opis, datum_dospijeca,
        broj_uplatnice, primalac, racun_primaoca,
        poziv_na_broj, model, sifra_placanja, qr_sadrzaj,
        stanovi ( oznaka, ulaz ),
        zgrade ( naziv, ulica, broj, grad )
      `)
      .eq('id', transakcija_id)
      .single();

    // RLS je sakrio red ⇒ za korisnika to izgleda kao "nema pristupa".
    if (error) return greska('Uplatnica nije pronađena ili nemate pristup', 404);

    return odgovor({ uplatnica: data });
  } catch (e) {
    console.error(e);
    return greska(e instanceof Error ? e.message : 'Nepoznata greška', 500);
  }
});
