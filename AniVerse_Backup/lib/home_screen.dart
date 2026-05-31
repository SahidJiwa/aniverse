import 'package:flutter/material.dart';
import 'mock_data_service.dart';
import 'anime_card.dart';
import 'section_title.dart';
import 'app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final animes = MockDataService.getMockAnimes();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(animes[0].imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppTheme.backgroundDark.withValues(alpha: 0.9)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(animes[0].title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Watch Now"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sakuraPink, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SectionTitle(title: "Trending Now"),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: animes.length,
                    itemBuilder: (context, index) => AnimeCard(anime: animes[index]),
                  ),
                ),
                const SectionTitle(title: "New Episodes"),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: animes.reversed.length,
                    itemBuilder: (context, index) => AnimeCard(anime: animes.reversed.toList()[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}