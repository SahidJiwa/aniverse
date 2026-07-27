import 'package:flutter/material.dart';
import 'components/section_header.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionTitle({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return SectionHeader(title: title, onSeeAll: onSeeAll);
  }
}
