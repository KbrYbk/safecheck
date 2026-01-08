import 'package:flutter/material.dart';
import 'package:safecheck/models/receipt.dart';
import 'package:safecheck/screens/receipt_details_screen.dart';
import 'package:intl/intl.dart';

class ExpiredReceiptsScreen extends StatelessWidget {
  final List<Receipt> receipts;

  const ExpiredReceiptsScreen({super.key, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Фильтруем истёкшие чеки
    final expiredReceipts = receipts
        .where((r) => r.warrantyEnd.isBefore(DateTime.now()))
        .toList();

    if (expiredReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 100, color: colorScheme.outline),
            const SizedBox(height: 24),
            Text(
              "Нет истёкших чеков",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              "Здесь будут чеки с закончившейся гарантией",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expiredReceipts.length,
      itemBuilder: (context, index) {
        final receipt = expiredReceipts[index];
        final dateFormat = DateFormat('dd.MM.yyyy');

        return Card(
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                color: colorScheme.onErrorContainer,
              ),
            ),
            title: Text(
              receipt.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Покупка: ${dateFormat.format(receipt.date)}",
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                Text(
                  "Гарантия закончилась: ${dateFormat.format(receipt.warrantyEnd)}",
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReceiptDetailsScreen(receipt: receipt)),
              );
            },
          ),
        );
      },
    );
  }
}