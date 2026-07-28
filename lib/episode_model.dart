class EpisodeModel {
  final int number;
  final String title;
  final String duration;
  final String thumbnailUrl;
  final String? airedDate;
  final String? videoUrl;

  const EpisodeModel({
    required this.number,
    required this.title,
    required this.duration,
    required this.thumbnailUrl,
    this.airedDate,
    this.videoUrl,
  });
}
