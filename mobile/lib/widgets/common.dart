import "package:flutter/material.dart";
import "../theme/app_theme.dart";

/// Status badge u boji (Pending/Confirmed/Completed/Cancelled).
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppColors.statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Prikaz zvjezdica (samo za citanje).
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  const StarRating(this.rating, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(filled ? Icons.star : Icons.star_border,
            size: size, color: AppColors.pending);
      }),
    );
  }
}

/// Interaktivni izbor zvjezdica (za ostavljanje recenzije).
class StarInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarInput({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        return IconButton(
          onPressed: () => onChanged(idx),
          icon: Icon(idx <= value ? Icons.star : Icons.star_border,
              size: 36, color: AppColors.pending),
        );
      }),
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error.toString()),
    backgroundColor: AppColors.cancelled,
  ));
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: AppColors.completed,
  ));
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyView(this.message, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}
