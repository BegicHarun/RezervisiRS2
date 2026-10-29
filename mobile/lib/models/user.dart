class UserDto {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? imageUrl;
  final String? cityName;
  final List<String> roles;

  UserDto({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.imageUrl,
    this.cityName,
    this.roles = const [],
  });

  String get fullName => "$firstName $lastName";

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
        id: j["id"],
        username: j["username"] ?? "",
        email: j["email"] ?? "",
        firstName: j["firstName"] ?? "",
        lastName: j["lastName"] ?? "",
        imageUrl: j["imageUrl"],
        cityName: j["cityName"],
        roles: (j["roles"] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class AuthResponse {
  final String token;
  final DateTime expiresAt;
  final UserDto user;

  AuthResponse({required this.token, required this.expiresAt, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j["token"],
        expiresAt: DateTime.parse(j["expiresAt"]),
        user: UserDto.fromJson(j["user"]),
      );
}
