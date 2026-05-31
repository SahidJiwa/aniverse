import 'package:flutter/material.dart';
import 'mock_data_service.dart';
import 'anime_card.dart';
import 'app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final animes = MockDataService.getMockAnimes();
    final genres = MockDataService.getGenres();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              hintText: "Search anime...",
              leading: const Icon(Icons.search),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
              backgroundColor: WidgetStateProperty.all(AppTheme.surfaceDark),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: genres.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(genres[index]),
                  onSelected: (_) {},
                  selectedColor: AppTheme.sakuraPink.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // Responsive grid sizing
              int crossAxisCount = constraints.maxWidth ~/ 150;
              if (crossAxisCount < 2) crossAxisCount = 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 10, // Mocking more items
                itemBuilder: (context, index) => AnimeCard(
                  anime: animes[index % animes.length],
                  width: double.infinity,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}