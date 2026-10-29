import "api_client.dart";
import "../models/user.dart";
import "../models/salon.dart";
import "../models/reservation.dart";

/// Tipizirani sloj iznad ApiClient-a - jedna metoda po endpointu.
class ApiService {
  final ApiClient _api;
  ApiService(this._api);

  ApiClient get client => _api;

  // ---- Auth ----
  Future<AuthResponse> login(String username, String password) async {
    final j = await _api.post("/auth/login",
        body: {"username": username, "password": password});
    return AuthResponse.fromJson(j);
  }

  Future<AuthResponse> register(Map<String, dynamic> body) async {
    final j = await _api.post("/auth/register", body: body);
    return AuthResponse.fromJson(j);
  }

  // ---- Saloni ----
  Future<PagedResult<SalonDto>> getSalons(
      {int page = 1, int pageSize = 20, String? search, int? cityId}) async {
    final j = await _api.get("/salons", query: {
      "page": page,
      "pageSize": pageSize,
      "search": search,
      "cityId": cityId,
    });
    return PagedResult.fromJson(j, SalonDto.fromJson);
  }

  Future<SalonDto> getSalon(int id) async {
    final j = await _api.get("/salons/$id");
    return SalonDto.fromJson(j);
  }

  // ---- Frizeri ----
  Future<List<HairdresserDto>> getSalonHairdressers(int salonId) async {
    final j = await _api.get("/hairdressers/salon/$salonId");
    return (j as List).map((e) => HairdresserDto.fromJson(e)).toList();
  }

  // ---- Usluge ----
  Future<PagedResult<ServiceDto>> getServices(
      {int page = 1,
      int pageSize = 50,
      int? salonId,
      int? categoryId,
      String? search}) async {
    final j = await _api.get("/services", query: {
      "page": page,
      "pageSize": pageSize,
      "salonId": salonId,
      "categoryId": categoryId,
      "search": search,
    });
    return PagedResult.fromJson(j, ServiceDto.fromJson);
  }

  // ---- Referentni podaci ----
  Future<PagedResult<CityDto>> getCities() async {
    final j = await _api.get("/cities", query: {"pageSize": 100});
    return PagedResult.fromJson(j, CityDto.fromJson);
  }

  Future<PagedResult<ServiceCategoryDto>> getCategories() async {
    final j = await _api.get("/categories", query: {"pageSize": 100});
    return PagedResult.fromJson(j, ServiceCategoryDto.fromJson);
  }

  Future<List<TagDto>> getTags() async {
    final j = await _api.get("/tags");
    return (j as List).map((e) => TagDto.fromJson(e)).toList();
  }

  // ---- Rezervacije ----
  Future<PagedResult<ReservationDto>> getMyReservations(
      {int page = 1, int pageSize = 50}) async {
    final j = await _api
        .get("/reservations/mine", query: {"page": page, "pageSize": pageSize});
    return PagedResult.fromJson(j, ReservationDto.fromJson);
  }

  Future<List<AvailableSlotDto>> getAvailableSlots(
      int hairdresserId, int serviceId, DateTime date) async {
    final d =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final j = await _api.get("/reservations/available-slots", query: {
      "hairdresserId": hairdresserId,
      "serviceId": serviceId,
      "date": d,
    });
    return (j as List).map((e) => AvailableSlotDto.fromJson(e)).toList();
  }

  Future<ReservationDto> createReservation(
      int hairdresserId, int serviceId, DateTime startTime) async {
    final j = await _api.post("/reservations", body: {
      "hairdresserId": hairdresserId,
      "serviceId": serviceId,
      "startTime": startTime.toUtc().toIso8601String(),
    });
    return ReservationDto.fromJson(j);
  }

  Future<ReservationDto> changeStatus(int id, String status,
      {String? reason}) async {
    final j = await _api.post("/reservations/$id/status",
        body: {"status": status, "reason": reason});
    return ReservationDto.fromJson(j);
  }

  Future<ReservationDto> cancelReservation(int id, String reason) =>
      changeStatus(id, "Cancelled", reason: reason);

  // ---- Placanje (PayPal) ----
  /// Kreira PayPal narudzbu za rezervaciju. Vraca {paymentId, orderId, approveUrl}.
  Future<Map<String, dynamic>> createPaymentOrder(int reservationId) async {
    final j = await _api
        .post("/payments/reservation/$reservationId/create-order");
    return j as Map<String, dynamic>;
  }

  /// Potvrdjuje (capture) placanje nakon odobrenja na PayPal-u.
  Future<Map<String, dynamic>> capturePayment(String orderId) async {
    final j = await _api.post("/payments/capture", body: {"orderId": orderId});
    return j as Map<String, dynamic>;
  }

  // ---- Recenzije ----
  Future<List<ReviewDto>> getSalonReviews(int salonId) async {
    final j = await _api.get("/reviews/salon/$salonId");
    return (j as List).map((e) => ReviewDto.fromJson(e)).toList();
  }

  Future<ReviewDto> createReview(
      int reservationId, int rating, String? comment, List<int> tagIds) async {
    final j = await _api.post("/reviews", body: {
      "reservationId": reservationId,
      "rating": rating,
      "comment": comment,
      "tagIds": tagIds,
    });
    return ReviewDto.fromJson(j);
  }

  // ---- Notifikacije ----
  Future<PagedResult<NotificationDto>> getNotifications(
      {int page = 1, int pageSize = 50}) async {
    final j = await _api
        .get("/notifications", query: {"page": page, "pageSize": pageSize});
    return PagedResult.fromJson(j, NotificationDto.fromJson);
  }

  Future<int> getUnreadCount() async {
    final j = await _api.get("/notifications/unread-count");
    return j as int;
  }

  Future<void> markNotificationRead(int id) async {
    await _api.post("/notifications/$id/read");
  }

  // ---- Preporuke ----
  Future<List<RecommendationDto>> getRecommendations({int take = 5}) async {
    final j = await _api.get("/recommendations", query: {"take": take});
    return (j as List).map((e) => RecommendationDto.fromJson(e)).toList();
  }

  // ---- Profil ----
  Future<UserDto> getProfile() async {
    final j = await _api.get("/profile");
    return UserDto.fromJson(j);
  }

  Future<UserDto> updateProfile(Map<String, dynamic> body) async {
    final j = await _api.put("/profile", body: body);
    return UserDto.fromJson(j);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post("/profile/change-password", body: {
      "currentPassword": currentPassword,
      "newPassword": newPassword,
    });
  }

  // ---- Odjava (server-side invalidacija tokena, uputa 5) ----
  Future<void> logout() async {
    await _api.post("/auth/logout");
  }
}
