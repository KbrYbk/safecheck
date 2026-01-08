import 'dart:io';
import 'package:flutter/material.dart';
import '../models/receipt.dart';
import 'package:intl/intl.dart';

class ReceiptDetailsScreen extends StatelessWidget {
  final Receipt receipt;

  const ReceiptDetailsScreen({super.key, required this.receipt});

  void _deleteReceipt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Удалить чек?"),
        content: const Text("Это действие нельзя отменить"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          FilledButton(
            onPressed: () async {
              await receipt.delete();
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context, {"delete": true});
              }
            },
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy');
    final isExpired = receipt.warrantyEnd.isBefore(DateTime.now());
    Widget buildInfoRow(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      color: label.contains("Гарантия") && isExpired
                          ? colorScheme.error
                          : colorScheme.onSurface,
                      fontWeight: label.contains("Гарантия") && isExpired ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Детали чека"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteReceipt(context),
            color: colorScheme.error,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (receipt.imagePath.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    File(receipt.imagePath),
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 32),

            Card(
              color: colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      receipt.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    buildInfoRow(Icons.shopping_bag_outlined, "Что купили", receipt.title),
                    buildInfoRow(Icons.calendar_today, "Дата покупки", dateFormat.format(receipt.date)),
                    buildInfoRow(Icons.verified, "Гарантия до", dateFormat.format(receipt.warrantyEnd)),
                    if (receipt.price.isNotEmpty) buildInfoRow(Icons.price_check, "Сумма", receipt.price),
                    if (receipt.store.isNotEmpty) buildInfoRow(Icons.store, "Магазин", receipt.store),
                    if (receipt.category.isNotEmpty) buildInfoRow(Icons.category, "Категория", receipt.category),
                    if (receipt.comment.isNotEmpty) buildInfoRow(Icons.note, "Комментарий", receipt.comment),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.delete_forever),
                label: const Text("Удалить чек", style: TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                onPressed: () => _deleteReceipt(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}