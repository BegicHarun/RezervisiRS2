import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/salon.dart";
import "../../models/reservation.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../reservations/reservation_detail_screen.dart";

/// Rezervacija u koracima: odabir frizera -> datum -> termin (color-coded) -> potvrda.
/// Backend racuna dostupnost i cijenu; slobodni termini zeleno, odabrani plavo.
class BookingScreen extends StatefulWidget {
  final SalonDto salon;
  final ServiceDto service;
  const BookingScreen({super.key, required this.salon, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<HairdresserDto> _hairdressers = [];
  HairdresserDto? _hairdresser;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  List<AvailableSlotDto> _slots = [];
  AvailableSlotDto? _selected;
  bool _loadingHd = true;
  bool _loadingSlots = false;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadHairdressers();
  }

  Future<void> _loadHairdressers() async {
    try {
      final list = await context
          .read<ApiService>()
          .getSalonHairdressers(widget.salon.id);
      setState(() {
        _hairdressers = list;
        _hairdresser = list.isNotEmpty ? list.first : null;
        _loadingHd = false;
      });
      if (_hairdresser != null) _loadSlots();
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHd = false);
        showError(context, e);
      }
    }
  }

  Future<void> _loadSlots() async {
    if (_hairdresser == null) return;
    setState(() {
      _loadingSlots = true;
      _selected = null;
    });
    try {
      final slots = await context.read<ApiService>().getAvailableSlots(
          _hairdresser!.id, widget.service.id, _date);
      setState(() => _slots = slots);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _loadSlots();
    }
  }

  Future<void> _confirm() async {
    if (_selected == null || _hairdresser == null) return;
    setState(() => _booking = true);
    try {
      final created = await context.read<ApiService>().createReservation(
          _hairdresser!.id, widget.service.id, _selected!.startTime);
      if (mounted) {
        showOk(context, "Rezervacija kreirana! Zavrsite placanje.");
        // Odmah vodi na detalje rezervacije gdje je dugme "Plati".
        // pushReplacement - da se vracanjem ne vratis na booking formu.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ReservationDetailScreen(reservation: created)),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("EEE, dd.MM.yyyy");
    final tf = DateFormat("HH:mm");

    return Scaffold(
      appBar: AppBar(title: const Text("Rezervacija")),
      body: _loadingHd
          ? const LoadingView()
          : _hairdressers.isEmpty
              ? const EmptyView("Ovaj salon trenutno nema frizera.",
                  icon: Icons.person_off_outlined)
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _StepHeader(1, "Usluga"),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  const Icon(Icons.content_cut,
                                      color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(widget.service.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            "${widget.service.durationMinutes} min · ${widget.service.price.toStringAsFixed(2)} KM",
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StepHeader(2, "Frizer i datum"),
                            if (_hairdressers.length > 1)
                              DropdownButtonFormField<HairdresserDto>(
                                initialValue: _hairdresser,
                                decoration:
                                    const InputDecoration(labelText: "Frizer"),
                                items: _hairdressers
                                    .map((h) => DropdownMenuItem(
                                        value: h,
                                        child: Text(
                                            "${h.fullName} · ${h.specialization}")))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => _hairdresser = v);
                                  _loadSlots();
                                },
                              )
                            else
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(_hairdresser!.fullName),
                                  subtitle: Text(_hairdresser!.specialization),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.calendar_today,
                                    color: AppColors.primary),
                                title: Text(df.format(_date)),
                                trailing: const Icon(Icons.edit_calendar),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StepHeader(3, "Termin"),
                            _Legend(),
                            const SizedBox(height: 12),
                            if (_loadingSlots)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: LoadingView(),
                              )
                            else if (_slots.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: EmptyView(
                                    "Nema slobodnih termina za ovaj dan.",
                                    icon: Icons.event_busy),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _slots.map((s) {
                                  final isSelected = _selected == s;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selected = s),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.slotSelected
                                            : AppColors.slotFree
                                                .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: isSelected
                                                ? AppColors.slotSelected
                                                : AppColors.slotFree),
                                      ),
                                      child: Text(
                                        tf.format(s.startTime),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.slotFree,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Sazetak + potvrda
                      if (_selected != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _summaryRow("Usluga", widget.service.name),
                                _summaryRow("Frizer", _hairdresser!.fullName),
                                _summaryRow(
                                    "Termin",
                                    "${df.format(_date)} u ${tf.format(_selected!.startTime)}"),
                                _summaryRow("Trajanje",
                                    "${widget.service.durationMinutes} min"),
                                const Divider(),
                                _summaryRow("Ukupno",
                                    "${widget.service.price.toStringAsFixed(2)} KM",
                                    bold: true),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _booking ? null : _confirm,
                                    child: _booking
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Text("Potvrdi rezervaciju"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int number;
  final String title;
  const _StepHeader(this.number, this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text("$number",
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]);
    return Row(children: [
      dot(AppColors.slotFree, "Slobodno"),
      const SizedBox(width: 16),
      dot(AppColors.slotSelected, "Odabrano"),
    ]);
  }
}
