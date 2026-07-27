// figure_model.dart — AniVerse Figure Collection
// Data model backing the "Figure Collection" card in Cosmetic Vault.
// Replaces the previously hardcoded "24/100" + 3 static chibi widgets with
// a real dataset that can be queried, counted, and (later) unlocked.

import 'package:flutter/material.dart';
import 'app_theme.dart';

enum FigureRarity { common, rare, epic, legendary }

extension FigureRarityX on FigureRarity {
  String get label => switch (this) {
        FigureRarity.common => 'Common',
        FigureRarity.rare => 'Rare',
        FigureRarity.epic => 'Epic',
        FigureRarity.legendary => 'Legendary',
      };

  Color get color => switch (this) {
        FigureRarity.common => const Color(0xFF9CA3AF),
        FigureRarity.rare => const Color(0xFF60A5FA),
        FigureRarity.epic => AppTheme.sage,
        FigureRarity.legendary => AppTheme.terracotta,
      };
}

class FigureModel {
  final String id;
  final String name;
  final String assetPath;
  final FigureRarity rarity;
  final bool owned;

  const FigureModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.rarity,
    required this.owned,
  });

  Color get glowColor => rarity.color;

  FigureModel copyWith({bool? owned}) => FigureModel(
        id: id,
        name: name,
        assetPath: assetPath,
        rarity: rarity,
        owned: owned ?? this.owned,
      );
}
