import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ljuska sa donjom navigacijom — pet modula iz specifikacije proizvoda.
class GlavnaLjuska extends StatelessWidget {
  const GlavnaLjuska({required this.ljuska, super.key});

  final StatefulNavigationShell ljuska;

  static const _odredista = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Početna',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Finansije',
    ),
    NavigationDestination(
      icon: Icon(Icons.how_to_vote_outlined),
      selectedIcon: Icon(Icons.how_to_vote),
      label: 'Glasanje',
    ),
    NavigationDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build),
      label: 'Kvarovi',
    ),
    NavigationDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment),
      label: 'Zgrada',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ljuska,
      bottomNavigationBar: NavigationBar(
        selectedIndex: ljuska.currentIndex,
        destinations: _odredista,
        onDestinationSelected: (i) => ljuska.goBranch(
          i,
          // Ponovni tap na aktivnu karticu vraća na korijen te grane.
          initialLocation: i == ljuska.currentIndex,
        ),
      ),
    );
  }
}
