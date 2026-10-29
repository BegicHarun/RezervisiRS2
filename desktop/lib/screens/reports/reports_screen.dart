import "dart:io";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "package:path_provider/path_provider.dart";
import "package:open_filex/open_filex.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _busy = false;

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _generate(bool revenue) async {
    setState(() => _busy = true);
    try {
      final api = context.read<ApiService>();
      final Uint8List bytes = revenue
          ? await api.revenueReport(_from, _to)
          : await api.popularServicesReport(_from, _to);

      final dir = await getApplicationDocumentsDirectory();
      final name = revenue
          ? "prihodi_${DateFormat('yyyyMMdd').format(_from)}_${DateFormat('yyyyMMdd').format(_to)}.pdf"
          : "popularne_usluge_${DateFormat('yyyyMMdd').format(_from)}_${DateFormat('yyyyMMdd').format(_to)}.pdf";
      final file = File("${dir.path}/$name");
      await file.writeAsBytes(bytes);

      if (mounted) showOk(context, "Sacuvano: ${file.path}");
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("dd.MM.yyyy");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader("Izvjestaji",
            subtitle: "PDF izvjestaji za preuzimanje i ispis"),
        const SizedBox(height: 20),
        // Period
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              const Text("Period:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text("Od: ${df.format(_from)}"),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text("Do: ${df.format(_to)}"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Kartice izvjestaja
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _reportCard(
                    title: "Izvjestaj o prihodima",
                    description:
                        "Prihodi po danima i uslugama, broj rezervacija i prosjecna vrijednost termina.",
                    icon: Icons.payments_outlined,
                    onGenerate: () => _generate(true))),
            const SizedBox(width: 16),
            Expanded(
                child: _reportCard(
                    title: "Popularne usluge",
                    description:
                        "Rangiranje usluga po broju rezervacija i prihodu za odabrani period.",
                    icon: Icons.leaderboard_outlined,
                    onGenerate: () => _generate(false))),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(child: Text("Generisanje PDF-a...")),
        ],
      ],
    );
  }

  Widget _reportCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onGenerate,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : onGenerate,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text("Generisi PDF"),
          ),
        ],
      ),
    );
  }
}
