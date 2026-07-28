// user_model.dart — AniVerse User Profile Model

class UserModel {
  final String id;
  final int accountIdNumber;
  final String name;
  final String email;
  final String photoUrl;
  final int level;
  final int xp;
  final int coins;
  final DateTime joinedAt;

  const UserModel({
    required this.id,
    this.accountIdNumber = 0,
    required this.name,
    required this.email,
    required this.photoUrl,
    this.level = 1,
    this.xp = 0,
    this.coins = 100,
    required this.joinedAt,
  });

  /// ID berbentuk unik rapi (misal: #0000 buat akun pertama, #0001 buat akun kedua)
  String get formattedAccountId => '#${accountIdNumber.toString().padLeft(4, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountIdNumber': accountIdNumber,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'level': level,
        'xp': xp,
        'coins': coins,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? 'guest',
        accountIdNumber: (json['accountIdNumber'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Pengunjung',
        email: json['email'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 100,
        joinedAt: json['joinedAt'] != null
            ? DateTime.parse(json['joinedAt'] as String)
            : DateTime.now(),
      );
}
