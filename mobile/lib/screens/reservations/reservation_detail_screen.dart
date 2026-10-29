import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/reservation.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../history/review_screen.dart";
import "payment_screen.dart";

class ReservationDetailScreen extends StatefulWidget {
  final ReservationDto reservation;
  const ReservationDetailScreen({super.key, required this.reservation});
  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late ReservationDto _r;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _r = widget.reservation;
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    // Otkazivanje je nepovratno -> confirmation dialog (uputa 6.3).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Otkazivanje rezervacije"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Ova radnja je nepovratna. Rezervacija ce biti otkazana."),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                  labelText: "Razlog otkazivanja (obavezno)"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Odustani")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.cancelled),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text("Otkazi rezervaciju"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ApiService>()
          .cancelReservation(_r.id, reasonController.text.trim());
      setState(() => _r = updated);
      if (mounted) showOk(context, "Rezervacija otkazana.");
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Placanje rezervacije preko PayPal-a (create-order -> WebView -> capture).
  Future<void> _pay() async {
    // Placanje je nepovratna akcija -> confirmation dialog (uputa 6.3).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Potvrda placanja"),
        content: Text(
            "Placate rezervaciju u iznosu ${_r.price.toStringAsFixed(2)} USD preko PayPal-a. "
            "Ova radnja je nepovratna. Zelite li nastaviti?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Odustani")),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070BA)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Plati"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final api = context.read<ApiService>();
      // 1) Kreiraj PayPal narudzbu na serveru.
      final order = await api.createPaymentOrder(_r.id);
      final approveUrl = order["approveUrl"] as String?;
      final orderId = order["orderId"] as String?;
      if (approveUrl == null || orderId == null) {
        throw Exception("Nije moguce pokrenuti placanje.");
      }

      // 2) Otvori PayPal checkout u WebView-u.
      if (!mounted) return;
      final approved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(approveUrl: approveUrl)),
      );

      if (approved != true) {
        if (mounted) showError(context, "Placanje otkazano.");
        return;
      }

      // 3) Potvrdi (capture) placanje na serveru - server-side verifikacija.
      final result = await api.capturePayment(orderId);
      if (result["status"] == "Completed") {
        if (mounted) showOk(context, "Placanje uspjesno!");
        // Osvjezi rezervaciju da se vidi "Placeno".
        setState(() => _r = ReservationDto(
              id: _r.id,
              clientId: _r.clientId,
              clientName: _r.clientName,
              hairdresserId: _r.hairdresserId,
              hairdresserName: _r.hairdresserName,
              serviceId: _r.serviceId,
              serviceName: _r.serviceName,
              salonName: _r.salonName,
              startTime: _r.startTime,
              endTime: _r.endTime,
              price: _r.price,
              status: _r.status,
              statusReason: _r.statusReason,
              canReview: _r.canReview,
              isPaid: true,
            ));
      } else {
        if (mounted) showError(context, "Placanje nije uspjelo.");
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("EEEE, dd.MM.yyyy");
    final tf = DateFormat("HH:mm");
    final canCancel = _r.status == "Pending" || _r.status == "Confirmed";

    return Scaffold(
      appBar: AppBar(title: Text("Rezervacija #${_r.id}")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: StatusBadge(_r.status)),
            const SizedBox(height: 20),
            _card([
              _row(Icons.content_cut, "Usluga", _r.serviceName),
              _row(Icons.store, "Salon", _r.salonName),
              _row(Icons.person_outline, "Frizer", _r.hairdresserName),
            ]),
            const SizedBox(height: 12),
            _card([
              _row(Icons.calendar_today, "Datum", df.format(_r.startTime)),
              _row(Icons.schedule, "Vrijeme",
                  "${tf.format(_r.startTime)} - ${tf.format(_r.endTime)}"),
              _row(Icons.payments_outlined, "Cijena",
                  "${_r.price.toStringAsFixed(2)} USD"),
            ]),
            if (_r.statusReason != null && _r.statusReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _card([
                _row(Icons.info_outline, "Razlog", _r.statusReason!),
              ]),
            ],
            const SizedBox(height: 12),
            // Status placanja
            _card([
              Row(
                children: [
                  Icon(_r.isPaid ? Icons.check_circle : Icons.pending_outlined,
                      size: 20,
                      color: _r.isPaid
                          ? AppColors.completed
                          : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Text("Placanje",
                      style: TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(_r.isPaid ? "Placeno" : "Nije placeno",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _r.isPaid
                              ? AppColors.completed
                              : AppColors.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            // Dugme za placanje - samo ako nije placeno i nije otkazano.
            if (!_r.isPaid && _r.status != "Cancelled")
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _pay,
                  icon: const Icon(Icons.payment),
                  label: Text("Plati ${_r.price.toStringAsFixed(2)} USD (PayPal)"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070BA), // PayPal plava
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            if (canCancel)
              OutlinedButton.icon(
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined,
                    color: AppColors.cancelled),
                label: const Text("Otkazi rezervaciju",
                    style: TextStyle(color: AppColors.cancelled)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cancelled),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            if (_r.canReview)
              ElevatedButton.icon(
                onPressed: () async {
                  final done = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ReviewScreen(reservation: _r)));
                  if (done == true && mounted) {
                    showOk(context, "Hvala na recenziji!");
                  }
                },
                icon: const Icon(Icons.star_outline),
                label: const Text("Ostavi recenziju"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: children),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
