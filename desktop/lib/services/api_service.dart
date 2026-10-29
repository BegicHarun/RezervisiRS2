import "dart:typed_data";
import "api_client.dart";
import "../models/core.dart";
import "../models/dashboard.dart";

class ApiService {
  final ApiClient _api;
  ApiService(this._api);
  ApiClient get client => _api;

  // ---- Auth ----
  Future<AuthResponse> login(String username, String password) async {
    final j = await _api
        .post("/auth/login", body: {"username": username, "password": password});
    return AuthResponse.fromJson(j);
  }

  Future<UserDto> getProfile() async =>
      UserDto.fromJson(await _api.get("/profile"));

  // ---- Dashboard ----
  Future<DashboardDto> getDashboard() async =>
      DashboardDto.fromJson(await _api.get("/dashboard"));

  // ---- Reservations ----
  Future<PagedResult<ReservationDto>> getReservations({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
  }) async {
    final j = await _api.get("/reservations", query: {
      "page": page,
      "pageSize": pageSize,
      "status": status,
      "search": search,
    });
    return PagedResult.fromJson(j, ReservationDto.fromJson);
  }

  Future<ReservationDto> changeStatus(int id, String status,
      {String? reason}) async {
    final j = await _api
        .post("/reservations/$id/status", body: {"status": status, "reason": reason});
    return ReservationDto.fromJson(j);
  }

  // ---- Services ----
  Future<PagedResult<ServiceDto>> getServices({
    int page = 1,
    int pageSize = 50,
    int? categoryId,
    String? search,
  }) async {
    final j = await _api.get("/services", query: {
      "page": page,
      "pageSize": pageSize,
      "categoryId": categoryId,
      "search": search,
    });
    return PagedResult.fromJson(j, ServiceDto.fromJson);
  }

  Future<ServiceDto> createService(Map<String, dynamic> body) async =>
      ServiceDto.fromJson(await _api.post("/services", body: body));
  Future<ServiceDto> updateService(int id, Map<String, dynamic> body) async =>
      ServiceDto.fromJson(await _api.put("/services/$id", body: body));
  Future<void> deleteService(int id) async => _api.delete("/services/$id");

  // ---- Hairdressers ----
  Future<PagedResult<HairdresserDto>> getHairdressers(
      {int page = 1, int pageSize = 50, int? salonId, String? search}) async {
    final j = await _api.get("/hairdressers",
        query: {"page": page, "pageSize": pageSize, "salonId": salonId, "search": search});
    return PagedResult.fromJson(j, HairdresserDto.fromJson);
  }

  Future<HairdresserDto> verifyHairdresser(int id, bool approve,
      {String? reason}) async {
    final j = await _api.post("/hairdressers/$id/verify",
        body: {"approve": approve, "rejectionReason": reason});
    return HairdresserDto.fromJson(j);
  }

  Future<HairdresserDto> createHairdresserWithAccount(
      Map<String, dynamic> body) async {
    final j = await _api.post("/hairdressers/with-account", body: body);
    return HairdresserDto.fromJson(j);
  }

  Future<List<WorkingHourDto>> getWorkingHours(int hairdresserId) async {
    final j = await _api.get("/hairdressers/$hairdresserId/working-hours");
    return (j as List).map((e) => WorkingHourDto.fromJson(e)).toList();
  }

  Future<List<WorkingHourDto>> setWorkingHours(
      int hairdresserId, List<Map<String, dynamic>> hours) async {
    final j = await _api.put("/hairdressers/$hairdresserId/working-hours", body: hours);
    return (j as List).map((e) => WorkingHourDto.fromJson(e)).toList();
  }

  // ---- Salons ----
  Future<PagedResult<SalonDto>> getSalons(
      {int page = 1, int pageSize = 50, String? search}) async {
    final j = await _api.get("/salons",
        query: {"page": page, "pageSize": pageSize, "search": search, "onlyApproved": false});
    return PagedResult.fromJson(j, SalonDto.fromJson);
  }

  Future<SalonDto> verifySalon(int id, bool approve, {String? reason}) async {
    final j = await _api
        .post("/salons/$id/verify", body: {"approve": approve, "rejectionReason": reason});
    return SalonDto.fromJson(j);
  }

  Future<SalonDto> createSalon(Map<String, dynamic> body) async =>
      SalonDto.fromJson(await _api.post("/salons", body: body));
  Future<SalonDto> updateSalon(int id, Map<String, dynamic> body) async =>
      SalonDto.fromJson(await _api.put("/salons/$id", body: body));
  Future<void> deleteSalon(int id) async => _api.delete("/salons/$id");

  // ---- Reference (cities, categories) ----
  Future<PagedResult<CityDto>> getCities() async {
    final j = await _api.get("/cities", query: {"pageSize": 100});
    return PagedResult.fromJson(j, CityDto.fromJson);
  }

  Future<CityDto> createCity(Map<String, dynamic> body) async =>
      CityDto.fromJson(await _api.post("/cities", body: body));
  Future<CityDto> updateCity(int id, Map<String, dynamic> body) async =>
      CityDto.fromJson(await _api.put("/cities/$id", body: body));
  Future<void> deleteCity(int id) async => _api.delete("/cities/$id");

  Future<PagedResult<ServiceCategoryDto>> getCategories() async {
    final j = await _api.get("/categories", query: {"pageSize": 100});
    return PagedResult.fromJson(j, ServiceCategoryDto.fromJson);
  }

  Future<ServiceCategoryDto> createCategory(Map<String, dynamic> body) async =>
      ServiceCategoryDto.fromJson(await _api.post("/categories", body: body));
  Future<ServiceCategoryDto> updateCategory(
          int id, Map<String, dynamic> body) async =>
      ServiceCategoryDto.fromJson(await _api.put("/categories/$id", body: body));
  Future<void> deleteCategory(int id) async => _api.delete("/categories/$id");

  // ---- Reports (PDF) ----
  Future<Uint8List> revenueReport(DateTime from, DateTime to) =>
      _api.getBytes("/reports/revenue", query: {
        "from": from.toIso8601String(),
        "to": to.toIso8601String(),
      });

  Future<Uint8List> popularServicesReport(DateTime from, DateTime to) =>
      _api.getBytes("/reports/popular-services", query: {
        "from": from.toIso8601String(),
        "to": to.toIso8601String(),
      });
}
