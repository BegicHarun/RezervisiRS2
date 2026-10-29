import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/reservation.dart";
import "../../models/salon.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ReviewScreen extends StatefulWidget {
  final ReservationDto reservation;
  const ReviewScreen({super.key, required this.reservation});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  final Set<int> _selectedTags = {};
  List<TagDto> _tags = [];
  bool _loadingTags = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await context.read<ApiService>().getTags();
      setState(() {
        _tags = tags;
        _loadingTags = false;
      });
    } catch (_) {
      setState(() => _loadingTags = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().createReview(
            widget.reservation.id,
            _rating,
            _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            _selectedTags.toList(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ostavi recenziju")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.reservation.salonName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.reservation.serviceName,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            const Center(
                child: Text("Kako ocjenjujes uslugu?",
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Center(
              child: StarInput(
                  value: _rating, onChanged: (v) => setState(() => _rating = v)),
            ),
            const SizedBox(height: 16),
            const Text("Brze oznake",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loadingTags)
              const LoadingView()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((t) {
                  final sel = _selectedTags.contains(t.id);
                  return FilterChip(
                    label: Text(t.name),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(t.id);
                      } else {
                        _selectedTags.remove(t.id);
                      }
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            const Text("Komentar (opcionalno)",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: "Podijeli svoje iskustvo..."),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Posalji recenziju"),
            ),
          ],
        ),
      ),
    );
  }
}
