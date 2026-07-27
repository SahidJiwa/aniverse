/// Represents a single voice actor entry as returned by
/// GET https://api.jikan.moe/v4/anime/{id}/characters
///
/// Each [VoiceActorModel] captures both the person's details
/// and the character they voice, so a dialog can display
/// everything with no additional network requests.
class VoiceActorModel {
  final int malId;
  final String name;
  final String imageUrl;
  final String language;
  final String characterName;
  final String characterImageUrl;

  const VoiceActorModel({
    required this.malId,
    required this.name,
    required this.imageUrl,
    required this.language,
    required this.characterName,
    required this.characterImageUrl,
  });

  /// Parses a single voice-actor entry from the flattened structure:
  ///
  /// ```json
  /// {
  ///   "person": {
  ///     "mal_id": 613,
  ///     "name": "Itou, Setsuo",
  ///     "images": { "jpg": { "image_url": "https://..." } }
  ///   },
  ///   "language": "Japanese",
  ///   "_characterName": "Reigen, Arataka",        // injected during parsing
  ///   "_characterImageUrl": "https://..."          // injected during parsing
  /// }
  /// ```
  factory VoiceActorModel.fromJson(
    Map<String, dynamic> vaJson, {
    required String characterName,
    required String characterImageUrl,
  }) {
    final person = vaJson['person'] as Map<String, dynamic>? ?? {};
    final images = person['images'] as Map<String, dynamic>? ?? {};
    final jpg = images['jpg'] as Map<String, dynamic>? ?? {};

    return VoiceActorModel(
      malId: (person['mal_id'] as num?)?.toInt() ?? 0,
      name: (person['name'] as String?) ?? 'Unknown',
      imageUrl: (jpg['image_url'] as String?) ?? '',
      language: (vaJson['language'] as String?) ?? '',
      characterName: characterName,
      characterImageUrl: characterImageUrl,
    );
  }
}
