import 'package:flutter/material.dart';
import '../widgets/themes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.gradient(Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceTint),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(
          child: Text('Welcome to the Home Page!'),
        ),
      ),
    );
  }
}