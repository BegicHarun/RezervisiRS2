import "package:flutter/material.dart";
import "../theme/app_theme.dart";

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
          borderRadius: BorderRadius.circular(8)),
      child: Text(AppColors.statusLabel(status),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
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

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHeader(this.title, {super.key, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.cancelled));
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.completed));
}

/// KPI kartica za dashboard.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double? trend;
  const KpiCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.trend});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const Spacer(),
                if (trend != null)
                  Row(
                    children: [
                      Icon(
                          trend! >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: trend! >= 0
                              ? AppColors.completed
                              : AppColors.cancelled),
                      const SizedBox(width: 2),
                      Text("${trend!.abs().toStringAsFixed(0)}%",
                          style: TextStyle(
                              fontSize: 12,
                              color: trend! >= 0
                                  ? AppColors.completed
                                  : AppColors.cancelled)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(value,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
