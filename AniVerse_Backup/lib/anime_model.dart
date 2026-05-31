class AnimeModel {
  final String id;
  final String title;
  final String imageUrl;
  final double rating;
  final String genre;
  final String description;
  final bool isTrending;

  AnimeModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genre,
    required this.description,
    this.isTrending = false,
  });
}