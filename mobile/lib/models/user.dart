class User {
  final int id;
  final String email;
  final String username;
  final String? fullName;
  final double privacyScore;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.privacyScore = 0,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'],
      privacyScore: (json['privacy_score'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class TokenResponse {
  final String accessToken;
  final String tokenType;

  TokenResponse({required this.accessToken, required this.tokenType});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
    );
  }
}
