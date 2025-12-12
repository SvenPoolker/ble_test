import 'package:flutter/material.dart';

class SecondPage extends StatelessWidget {
  final int compteur;

  const SecondPage({super.key, required this.compteur});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Page 2'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('Bienvenue sur la deuxième page !'),
            Text("Le compteur vaut : $compteur"),
          ],
        ),
      ),
    );
  }
}