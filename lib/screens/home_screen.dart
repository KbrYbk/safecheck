import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:safecheck/models/receipt.dart';
import 'package:safecheck/screens/add_receipt_screen.dart';
import 'package:safecheck/screens/expired_receipts_screen.dart';
import 'package:safecheck/screens/profile_screen.dart';
import 'package:safecheck/screens/receipt_details_screen.dart';
import 'package:safecheck/screens/settings_screen.dart';
import '../services/theme_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;

  const HomeScreen({super.key, required this.themeService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Виджет подзаголовка чека
class ReceiptSubtitle extends StatelessWidget {
  final Receipt receipt;

  const ReceiptSubtitle({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Покупка: ${dateFormat.format(receipt.date)}",
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        Text(
          "Гарантия до: ${dateFormat.format(receipt.warrantyEnd)}",
          style: TextStyle(
            color: receipt.warrantyEnd.isBefore(DateTime.now())
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: receipt.warrantyEnd.isBefore(DateTime.now().add(const Duration(days: 30)))
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Box<Receipt> _receiptBox;

  @override
  void initState() {
    super.initState();
    _receiptBox = Hive.box<Receipt>('receipts');
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _addReceipt() async {
    final newReceipt = await Navigator.push<Receipt?>(
      context,
      MaterialPageRoute(builder: (_) => const AddReceiptScreen()),
    );

    if (newReceipt != null) {
      await _receiptBox.add(newReceipt);
    }
  }

  Future<void> _openReceiptDetails(Receipt receipt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptDetailsScreen(receipt: receipt)),
    );

    if (result != null && result["delete"] == true) {
      setState(() {});
    }
  }

  Widget? _buildFloatingButton() {
    if (_selectedIndex != 0) return null;
    return FloatingActionButton(
      onPressed: _addReceipt,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final pages = {
      0: ValueListenableBuilder(
        valueListenable: _receiptBox.listenable(),
        builder: (context, Box<Receipt> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 100, color: colorScheme.outline),
                  const SizedBox(height: 24),
                  Text(
                    "Пока нет сохранённых чеков",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Нажмите + чтобы добавить первый",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final receipts = box.values.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];

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
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    receipt.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  subtitle: ReceiptSubtitle(receipt: receipt),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  onTap: () => _openReceiptDetails(receipt),
                ),
              );
            },
          );
        },
      ),
      1: ValueListenableBuilder(
        valueListenable: _receiptBox.listenable(),
        builder: (context, Box<Receipt> box, _) {
          final expired = box.values.where((r) => r.warrantyEnd.isBefore(DateTime.now())).toList();
          return ExpiredReceiptsScreen(receipts: expired);
        },
      ),
      2: const ProfileScreen(),
      3: SettingsScreen(
        themeService: widget.themeService,
        notificationsEnabled: true, // передай правильно, если нужно
        onNotificationsChanged: (val) {},
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Гарантийные чеки"),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
      ),
      body: pages[_selectedIndex]!,
      floatingActionButton: _buildFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_outlined), selectedIcon: Icon(Icons.receipt), label: "Чеки"),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: "Истёкшие"),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "Профиль"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: "Настройки"),
        ],
      ),
    );
  }
}