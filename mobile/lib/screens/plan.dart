import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan an outing')),
      body: const Center(child: Text('Plan an outing from your saved places.')),
    );
  }
}
