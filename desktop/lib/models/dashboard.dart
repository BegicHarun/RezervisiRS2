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
  final String? auditSummary;
  final String? lastActionBy;

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
    this.auditSummary,
    this.lastActionBy,
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
        startTime: DateTime.parse(j["startTime"]).toLocal(),
        endTime: DateTime.parse(j["endTime"]).toLocal(),
        price: (j["price"] ?? 0).toDouble(),
        status: j["status"] ?? "",
        statusReason: j["statusReason"],
        auditSummary: j["auditSummary"],
        lastActionBy: j["lastActionBy"],
      );
}

class DashboardDto {
  final int totalReservations;
  final double totalRevenue;
  final int newClients;
  final double occupancyRate;
  final double reservationsTrend;
  final double revenueTrend;
  final List<DailyCount> reservationsPerDay;
  final List<StatusCount> reservationsByStatus;
  final List<PopularService> popularServices;
  final List<ReservationDto> recentReservations;

  DashboardDto({
    required this.totalReservations,
    required this.totalRevenue,
    required this.newClients,
    required this.occupancyRate,
    required this.reservationsTrend,
    required this.revenueTrend,
    required this.reservationsPerDay,
    required this.reservationsByStatus,
    required this.popularServices,
    required this.recentReservations,
  });

  factory DashboardDto.fromJson(Map<String, dynamic> j) => DashboardDto(
        totalReservations: j["totalReservations"] ?? 0,
        totalRevenue: (j["totalRevenue"] ?? 0).toDouble(),
        newClients: j["newClients"] ?? 0,
        occupancyRate: (j["occupancyRate"] ?? 0).toDouble(),
        reservationsTrend: (j["reservationsTrend"] ?? 0).toDouble(),
        revenueTrend: (j["revenueTrend"] ?? 0).toDouble(),
        reservationsPerDay: (j["reservationsPerDay"] as List? ?? [])
            .map((e) => DailyCount.fromJson(e))
            .toList(),
        reservationsByStatus: (j["reservationsByStatus"] as List? ?? [])
            .map((e) => StatusCount.fromJson(e))
            .toList(),
        popularServices: (j["popularServices"] as List? ?? [])
            .map((e) => PopularService.fromJson(e))
            .toList(),
        recentReservations: (j["recentReservations"] as List? ?? [])
            .map((e) => ReservationDto.fromJson(e))
            .toList(),
      );
}

class DailyCount {
  final String label;
  final int count;
  DailyCount({required this.label, required this.count});
  factory DailyCount.fromJson(Map<String, dynamic> j) =>
      DailyCount(label: j["label"] ?? "", count: j["count"] ?? 0);
}

class StatusCount {
  final String status;
  final int count;
  StatusCount({required this.status, required this.count});
  factory StatusCount.fromJson(Map<String, dynamic> j) =>
      StatusCount(status: j["status"] ?? "", count: j["count"] ?? 0);
}

class PopularService {
  final int serviceId;
  final String serviceName;
  final int reservationCount;
  final double revenue;
  PopularService({
    required this.serviceId,
    required this.serviceName,
    required this.reservationCount,
    required this.revenue,
  });
  factory PopularService.fromJson(Map<String, dynamic> j) => PopularService(
        serviceId: j["serviceId"] ?? 0,
        serviceName: j["serviceName"] ?? "",
        reservationCount: j["reservationCount"] ?? 0,
        revenue: (j["revenue"] ?? 0).toDouble(),
      );
}
