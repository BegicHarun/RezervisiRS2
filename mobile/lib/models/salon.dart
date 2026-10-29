class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
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
    );
  }
}

class SalonDto {
  final int id;
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final int cityId;
  final String cityName;
  final String verificationStatus;
  final double averageRating;
  final int reviewCount;
  final List<String> imageUrls;

  SalonDto({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    required this.cityId,
    required this.cityName,
    required this.verificationStatus,
    required this.averageRating,
    required this.reviewCount,
    this.imageUrls = const [],
  });

  factory SalonDto.fromJson(Map<String, dynamic> j) => SalonDto(
        id: j["id"],
        name: j["name"] ?? "",
        address: j["address"] ?? "",
        description: j["description"],
        imageUrl: j["imageUrl"],
        cityId: j["cityId"] ?? 0,
        cityName: j["cityName"] ?? "",
        verificationStatus: j["verificationStatus"] ?? "",
        averageRating: (j["averageRating"] ?? 0).toDouble(),
        reviewCount: j["reviewCount"] ?? 0,
        imageUrls:
            (j["imageUrls"] as List?)?.map((e) => e.toString()).toList() ?? [],
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

class CityDto {
  final int id;
  final String name;
  final String region;
  CityDto({required this.id, required this.name, required this.region});
  factory CityDto.fromJson(Map<String, dynamic> j) =>
      CityDto(id: j["id"], name: j["name"] ?? "", region: j["region"] ?? "");
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

class TagDto {
  final int id;
  final String name;
  TagDto({required this.id, required this.name});
  factory TagDto.fromJson(Map<String, dynamic> j) =>
      TagDto(id: j["id"], name: j["name"] ?? "");
}
