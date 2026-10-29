class ReservationDto {
  final int id;
  final int clientId;
  final String clientName;
  final int hairdresserId;
  final String hairdresserName;
  final int serviceId;
  final String serviceName;
  final String salonName;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final String status;
  final String? statusReason;
  final bool canReview;
  final bool isPaid;

  ReservationDto({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.hairdresserId,
    required this.hairdresserName,
    required this.serviceId,
    required this.serviceName,
    required this.salonName,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
    this.statusReason,
    required this.canReview,
    this.isPaid = false,
  });

  factory ReservationDto.fromJson(Map<String, dynamic> j) => ReservationDto(
        id: j["id"],
        clientId: j["clientId"] ?? 0,
        clientName: j["clientName"] ?? "",
        hairdresserId: j["hairdresserId"] ?? 0,
        hairdresserName: j["hairdresserName"] ?? "",
        serviceId: j["serviceId"] ?? 0,
        serviceName: j["serviceName"] ?? "",
        salonName: j["salonName"] ?? "",
        startTime: DateTime.parse(j["startTime"]),
        endTime: DateTime.parse(j["endTime"]),
        price: (j["price"] ?? 0).toDouble(),
        status: j["status"] ?? "",
        statusReason: j["statusReason"],
        canReview: j["canReview"] ?? false,
        isPaid: j["isPaid"] ?? false,
      );
}

class AvailableSlotDto {
  final DateTime startTime;
  final DateTime endTime;
  AvailableSlotDto({required this.startTime, required this.endTime});
  factory AvailableSlotDto.fromJson(Map<String, dynamic> j) => AvailableSlotDto(
        startTime: DateTime.parse(j["startTime"]),
        endTime: DateTime.parse(j["endTime"]),
      );
}

class ReviewDto {
  final int id;
  final int reservationId;
  final int salonId;
  final String clientName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final List<String> tags;

  ReviewDto({
    required this.id,
    required this.reservationId,
    required this.salonId,
    required this.clientName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.tags = const [],
  });

  factory ReviewDto.fromJson(Map<String, dynamic> j) => ReviewDto(
        id: j["id"],
        reservationId: j["reservationId"] ?? 0,
        salonId: j["salonId"] ?? 0,
        clientName: j["clientName"] ?? "",
        rating: j["rating"] ?? 0,
        comment: j["comment"],
        createdAt: DateTime.parse(j["createdAt"]),
        tags: (j["tags"] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class NotificationDto {
  final int id;
  final String title;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.title,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> j) => NotificationDto(
        id: j["id"],
        title: j["title"] ?? "",
        text: j["text"] ?? "",
        isRead: j["isRead"] ?? false,
        createdAt: DateTime.parse(j["createdAt"]),
      );
}

class RecommendationDto {
  final int salonId;
  final String salonName;
  final String cityName;
  final String? imageUrl;
  final double averageRating;
  final int reviewCount;
  final double score;
  final String explanation;

  RecommendationDto({
    required this.salonId,
    required this.salonName,
    required this.cityName,
    this.imageUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.score,
    required this.explanation,
  });

  factory RecommendationDto.fromJson(Map<String, dynamic> j) => RecommendationDto(
        salonId: j["salonId"],
        salonName: j["salonName"] ?? "",
        cityName: j["cityName"] ?? "",
        imageUrl: j["imageUrl"],
        averageRating: (j["averageRating"] ?? 0).toDouble(),
        reviewCount: j["reviewCount"] ?? 0,
        score: (j["score"] ?? 0).toDouble(),
        explanation: j["explanation"] ?? "",
      );
}
