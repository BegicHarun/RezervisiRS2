class UserDto {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;

  UserDto({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.roles = const [],
  });

  String get fullName => "$firstName $lastName";

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
        id: j["id"],
        username: j["username"] ?? "",
        email: j["email"] ?? "",
        firstName: j["firstName"] ?? "",
        lastName: j["lastName"] ?? "",
        roles: (j["roles"] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class AuthResponse {
  final String token;
  final UserDto user;
  AuthResponse({required this.token, required this.user});
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j["token"],
        user: UserDto.fromJson(j["user"]),
      );
}

class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedResult.fromJson(
      Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) {
    return PagedResult(
      items: (j["items"] as List? ?? [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList(),
      totalCount: j["totalCount"] ?? 0,
      page: j["page"] ?? 1,
      pageSize: j["pageSize"] ?? 20,
      totalPages: j["totalPages"] ?? 1,
    );
  }
}

class SalonDto {
  final int id;
  final String name;
  final String address;
  final String? description;
  final int cityId;
  final String cityName;
  final String verificationStatus;
  final double averageRating;
  final int reviewCount;

  SalonDto({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.cityId,
    required this.cityName,
    required this.verificationStatus,
    required this.averageRating,
    required this.reviewCount,
  });

  factory SalonDto.fromJson(Map<String, dynamic> j) => SalonDto(
        id: j["id"],
        name: j["name"] ?? "",
        address: j["address"] ?? "",
        description: j["description"],
        cityId: j["cityId"] ?? 0,
        cityName: j["cityName"] ?? "",
        verificationStatus: j["verificationStatus"] ?? "",
        averageRating: (j["averageRating"] ?? 0).toDouble(),
        reviewCount: j["reviewCount"] ?? 0,
      );
}

class ServiceDto {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final int salonId;
  final String salonName;
  final int serviceCategoryId;
  final String serviceCategoryName;
  final bool isActive;

  ServiceDto({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationMinutes,
    required this.salonId,
    required this.salonName,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
    required this.isActive,
  });

  factory ServiceDto.fromJson(Map<String, dynamic> j) => ServiceDto(
        id: j["id"],
        name: j["name"] ?? "",
        description: j["description"],
        price: (j["price"] ?? 0).toDouble(),
        durationMinutes: j["durationMinutes"] ?? 0,
        salonId: j["salonId"] ?? 0,
        salonName: j["salonName"] ?? "",
        serviceCategoryId: j["serviceCategoryId"] ?? 0,
        serviceCategoryName: j["serviceCategoryName"] ?? "",
        isActive: j["isActive"] ?? true,
      );
}

class CityDto {
  final int id;
  final String name;
  final String region;
  final int salonCount;
  CityDto(
      {required this.id,
      required this.name,
      required this.region,
      this.salonCount = 0});
  factory CityDto.fromJson(Map<String, dynamic> j) => CityDto(
        id: j["id"],
        name: j["name"] ?? "",
        region: j["region"] ?? "",
        salonCount: j["salonCount"] ?? 0,
      );
}

class ServiceCategoryDto {
  final int id;
  final String name;
  final String? iconName;
  ServiceCategoryDto({required this.id, required this.name, this.iconName});
  factory ServiceCategoryDto.fromJson(Map<String, dynamic> j) =>
      ServiceCategoryDto(
          id: j["id"], name: j["name"] ?? "", iconName: j["iconName"]);
}

class HairdresserDto {
  final int id;
  final int userId;
  final String fullName;
  final String specialization;
  final int salonId;
  final String salonName;
  final String verificationStatus;

  HairdresserDto({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.specialization,
    required this.salonId,
    required this.salonName,
    required this.verificationStatus,
  });

  factory HairdresserDto.fromJson(Map<String, dynamic> j) => HairdresserDto(
        id: j["id"],
        userId: j["userId"] ?? 0,
        fullName: j["fullName"] ?? "",
        specialization: j["specialization"] ?? "",
        salonId: j["salonId"] ?? 0,
        salonName: j["salonName"] ?? "",
        verificationStatus: j["verificationStatus"] ?? "",
      );
}

class WorkingHourDto {
  final int id;
  final int dayOfWeek;
  final String dayName;
  final String startTime;
  final String endTime;
  final bool isDayOff;

  WorkingHourDto({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.isDayOff,
  });

  factory WorkingHourDto.fromJson(Map<String, dynamic> j) => WorkingHourDto(
        id: j["id"] ?? 0,
        dayOfWeek: j["dayOfWeek"] ?? 0,
        dayName: j["dayName"] ?? "",
        startTime: j["startTime"] ?? "09:00",
        endTime: j["endTime"] ?? "17:00",
        isDayOff: j["isDayOff"] ?? false,
      );
}
