import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../../core/errors/greske.dart';
import '../../../core/supabase/supabase_servis.dart';

/// Unos jednokratnog koda (OTP) primljenog SMS-om/Viberom ili emailom.
class OtpEkran extends ConsumerStatefulWidget {
  const OtpEkran({required this.kontakt, super.key});

  final String kontakt;

  @override
  ConsumerState<OtpEkran> createState() => _OtpEkranState();
}

class _OtpEkranState extends ConsumerState<OtpEkran> {
  final _kontroler = TextEditingController();
  bool _ucitava = false;

  bool get _jeEmail => widget.kontakt.contains('@');

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  Future<void> _potvrdi() async {
    final kod = _kontroler.text.trim();
    if (kod.length < 6) return;

    setState(() => _ucitava = true);
    try {
      await mapirajGresku(() async {
        await ref.read(supabaseProvider).auth.verifyOTP(
              type: _jeEmail ? OtpType.email : OtpType.sms,
              token: kod,
              email: _jeEmail ? widget.kontakt : null,
              phone: _jeEmail ? null : widget.kontakt,
            );
      });
      // Preusmjeravanje obavlja `redirect` u go_router-u.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Potvrda koda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text('Kod smo poslali na ${widget.kontakt}',
                  textAlign: TextAlign.center,),
              const SizedBox(height: 24),
              TextField(
                controller: _kontroler,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: const InputDecoration(counterText: ''),
                onChanged: (v) {
                  if (v.length == 6) _potvrdi();
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _ucitava ? null : _potvrdi,
                child: const Text('Potvrdi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
