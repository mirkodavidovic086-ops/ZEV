import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/greske.dart';
import '../../../core/router/rute.dart';
import '../../../core/supabase/supabase_servis.dart';
import '../../../core/theme/tema.dart';

/// Prijava bez lozinke: OTP na telefon (SMS/Viber) ili magic link na email.
class PrijavaEkran extends ConsumerStatefulWidget {
  const PrijavaEkran({super.key});

  @override
  ConsumerState<PrijavaEkran> createState() => _PrijavaEkranState();
}

class _PrijavaEkranState extends ConsumerState<PrijavaEkran> {
  final _kontroler = TextEditingController();
  bool _telefonom = true;
  bool _ucitava = false;

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  Future<void> _posalji() async {
    final unos = _kontroler.text.trim();
    if (unos.isEmpty) return;

    setState(() => _ucitava = true);
    try {
      final auth = ref.read(supabaseProvider).auth;
      await mapirajGresku(() async {
        if (_telefonom) {
          await auth.signInWithOtp(phone: unos);
        } else {
          await auth.signInWithOtp(email: unos);
        }
      });
      if (!mounted) return;
      context.go('${Rute.otp}?kontakt=$unos');
    } on AppGreska catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.poruka)));
    } finally {
      if (mounted) setState(() => _ucitava = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.apartment, size: 72, color: Tema.primarna),
                const SizedBox(height: 16),
                Text('MojZEV',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),),
                const SizedBox(height: 8),
                Text(
                  'Vodite svoju zgradu sami — transparentno i bez agencije.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(color: tema.colorScheme.outline),
                ),
                const SizedBox(height: 32),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.sms_outlined),
                        label: Text('Telefon'),),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.mail_outline),
                        label: Text('Email'),),
                  ],
                  selected: {_telefonom},
                  onSelectionChanged: (s) =>
                      setState(() => _telefonom = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _kontroler,
                  keyboardType: _telefonom
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  autofillHints: [
                    _telefonom
                        ? AutofillHints.telephoneNumber
                        : AutofillHints.email,
                  ],
                  decoration: InputDecoration(
                    labelText: _telefonom ? 'Broj telefona' : 'Email adresa',
                    hintText: _telefonom ? '+387 6x xxx xxx' : 'ime@primjer.ba',
                    prefixIcon: Icon(
                        _telefonom ? Icons.phone_outlined : Icons.alternate_email,),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _ucitava ? null : _posalji,
                  child: _ucitava
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),)
                      : const Text('Pošalji kod'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nema lozinki. Poslaćemo vam jednokratni kod.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
