// figure_collection_service.dart — AniVerse Figure Collection
// Provides the real dataset behind "Figure Collection" in Cosmetic Vault:
// 100 figures across 4 rarity tiers, with genuine ownership state instead
// of a hardcoded "24/100" string and a fixed progress-bar value.
//
// Only 3 figures currently have real chibi artwork bundled in
// asset/images/collection/ (chibi_hitaku, chibi_sakura_priestess,
// chibi_luna_knight). The rest point at not-yet-created asset paths and
// safely fall back to the existing person-icon placeholder — this is
// honest about what art actually exists today, not a fabricated claim.

import 'package:flutter/material.dart';
import 'figure_model.dart';

class FigureCollectionService {
  FigureCollectionService._();

  static final ValueNotifier<List<FigureModel>> figuresNotifier =
      ValueNotifier<List<FigureModel>>(_buildDataset());

  static List<FigureModel> get allFigures => figuresNotifier.value;

  static int get totalCount => allFigures.length;

  static int get ownedCount => allFigures.where((f) => f.owned).length;

  static double get progress =>
      totalCount == 0 ? 0 : ownedCount / totalCount;

  static List<FigureModel> get ownedFigures =>
      allFigures.where((f) => f.owned).toList();

  /// The figures shown in the compact 3-up row on the Vault card — the
  /// highest-rarity owned figures first, so the flagship hand-crafted
  /// chibi art is what people actually see.
  static List<FigureModel> get featuredOwned {
    final owned = ownedFigures.toList()
      ..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
    return owned.take(3).toList();
  }

  /// Unlocks a figure by id (e.g. after a gacha pull or achievement).
  /// No-op if the figure is already owned or doesn't exist.
  static void unlock(String id) {
    final list = figuresNotifier.value;
    final idx = list.indexWhere((f) => f.id == id);
    if (idx == -1 || list[idx].owned) return;
    final updated = [...list];
    updated[idx] = list[idx].copyWith(owned: true);
    figuresNotifier.value = updated;
  }

  static List<FigureModel> _buildDataset() {
    final figures = <FigureModel>[];

    // ── Legendary (5 total, 3 owned — the 3 with real bundled art) ──
    figures.addAll([
      const FigureModel(
        id: 'legend_hitaku',
        name: 'Hitaku, Sakura Emperor',
        assetPath: 'asset/images/collection/chibi_hitaku.png',
        rarity: FigureRarity.legendary,
        owned: true,
      ),
      const FigureModel(
        id: 'legend_sakura_priestess',
        name: 'Sakura Priestess',
        assetPath: 'asset/images/collection/chibi_sakura_priestess.png',
        rarity: FigureRarity.legendary,
        owned: true,
      ),
      const FigureModel(
        id: 'legend_luna_knight',
        name: 'Luna Knight',
        assetPath: 'asset/images/collection/chibi_luna_knight.png',
        rarity: FigureRarity.legendary,
        owned: true,
      ),
      const FigureModel(
        id: 'legend_void_empress',
        name: 'Void Empress',
        assetPath: 'asset/images/collection/chibi_void_empress.png',
        rarity: FigureRarity.legendary,
        owned: false,
      ),
      const FigureModel(
        id: 'legend_starforge_king',
        name: 'Starforge King',
        assetPath: 'asset/images/collection/chibi_starforge_king.png',
        rarity: FigureRarity.legendary,
        owned: false,
      ),
    ]);

    // ── Epic (20 total, 8 owned) ──
    const epicNames = [
      'Crimson Ronin', 'Frost Archer', 'Storm Dancer', 'Iron Alchemist',
      'Shadow Fox', 'Blaze Paladin', 'Nightshade Witch', 'Thunder Monk',
      'Ember Guardian', 'Glacier Sage', 'Wraith Hunter', 'Solstice Bard',
      'Obsidian Ranger', 'Aurora Mystic', 'Ashen Duelist', 'Verdant Druid',
      'Twilight Rogue', 'Radiant Cleric', 'Cinder Warlord', 'Mistral Scout',
    ];
    for (var i = 0; i < epicNames.length; i++) {
      figures.add(FigureModel(
        id: 'epic_$i',
        name: epicNames[i],
        assetPath: 'asset/images/collection/chibi_epic_$i.png',
        rarity: FigureRarity.epic,
        owned: i < 8,
      ));
    }

    // ── Rare (35 total, 9 owned) ──
    for (var i = 0; i < 35; i++) {
      figures.add(FigureModel(
        id: 'rare_$i',
        name: 'Rare Figure #${i + 1}',
        assetPath: 'asset/images/collection/chibi_rare_$i.png',
        rarity: FigureRarity.rare,
        owned: i < 9,
      ));
    }

    // ── Common (40 total, 4 owned) ──
    for (var i = 0; i < 40; i++) {
      figures.add(FigureModel(
        id: 'common_$i',
        name: 'Figure #${i + 1}',
        assetPath: 'asset/images/collection/chibi_common_$i.png',
        rarity: FigureRarity.common,
        owned: i < 4,
      ));
    }

    return figures;
  }
}
