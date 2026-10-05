class UserModel {
  final String id;
  final String email;
  final String role;
  final String locale;
  final String numeralSystem;
  final bool emailVerified;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.locale,
    required this.numeralSystem,
    required this.emailVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'user',
      locale: (json['locale'] as String?) ?? 'en',
      numeralSystem: (json['numeralSystem'] as String?) ?? 'western',
      emailVerified: (json['emailVerified'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'locale': locale,
      'numeralSystem': numeralSystem,
      'emailVerified': emailVerified,
    };
  }
}

class AuthResponseModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;

  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    final tokensJson = json['tokens'] as Map<String, dynamic>;
    return AuthResponseModel(
      user: UserModel.fromJson(userJson),
      accessToken: tokensJson['accessToken'] as String,
      refreshToken: tokensJson['refreshToken'] as String,
      expiresInSeconds: (tokensJson['expiresInSeconds'] as num).toInt(),
    );
  }
}
