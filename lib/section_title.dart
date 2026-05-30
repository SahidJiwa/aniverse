import 'package:flutter/material.dart';
import 'app_theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionTitle({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.sakuraPink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          if (onSeeAll != null)
            TextButton(
                onPressed: onSeeAll, child: const Text("See All", style: TextStyle(color: AppTheme.sakuraPink))),
        ],
      ),
    );
  }
}