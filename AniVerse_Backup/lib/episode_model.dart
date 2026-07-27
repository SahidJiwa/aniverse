class EpisodeModel {
  final int number;
  final String title;
  final String duration;
  final String thumbnailUrl;
  final String? airedDate;

  const EpisodeModel({
    required this.number,
    required this.title,
    required this.duration,
    required this.thumbnailUrl,
    this.airedDate,
  });
}
