import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:safecheck/models/receipt.dart';
import 'package:safecheck/screens/add_receipt_screen.dart';
import 'package:safecheck/screens/expired_receipts_screen.dart';
import 'package:safecheck/screens/profile_screen.dart';
import 'package:safecheck/screens/receipt_details_screen.dart';
import 'package:safecheck/screens/settings_screen.dart';
import '../services/theme_service.dart';
import '../services/alarm_notification_service.dart';

import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;

  const HomeScreen({super.key, required this.themeService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Виджет для вывода даты покупки и окончания гарантии
class ReceiptSubtitle extends StatelessWidget {
  final Receipt receipt;

  const ReceiptSubtitle({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Дата покупки: ${receipt.date}"),
        Text("Гарантия до: ${receipt.warrantyEnd}"),
      ],
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _notificationsEnabled = true;
  late Box<Receipt> _receiptBox; // Hive Box для хранения чеков

  @override
  void initState() {
    super.initState();
    _receiptBox = Hive.box<Receipt>('receipts');
//  AlarmNotificationService.rescheduleAll();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // Добавление нового чека

  Future<void> _addReceipt() async {
    final newReceipt = await Navigator.push<Receipt?>(
      context,
      MaterialPageRoute(builder: (_) => const AddReceiptScreen()),
    );

    if (newReceipt != null) {
      await _receiptBox.add(newReceipt);
    }
  }

//Открытие деталей чека
  Future<void> _openReceiptDetails(Receipt receipt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptDetailsScreen(receipt: receipt), // передаём объект Receipt
      ),
    );

    if (result != null && result["delete"] == true) {
      setState(() {}); // обновляем экран, объект уже удалён
    }
  }
//кнопка
Widget? _buildFloatingButton() {
  if (_selectedIndex != 0) return null;
  return FloatingActionButton(
    onPressed: _addReceipt,
    child: const Icon(Icons.add),
  );
}

@override
Widget build(BuildContext context) {
  final pages = {
    //вкладка чеки
    0: ValueListenableBuilder(
      valueListenable: _receiptBox.listenable(),
      builder: (context, Box<Receipt> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("Пока нет сохранённых чеков"));
        }

        final receipts = box.values.toList();

        return ListView.builder(
          itemCount: receipts.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            return Card(
              margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                title: Text(receipt.title),
                subtitle: ReceiptSubtitle(receipt: receipt),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openReceiptDetails(receipt),
              ),
            );
          },
        );
      },
    ),
    1: ValueListenableBuilder(//истёшие чеки
      valueListenable: _receiptBox.listenable(),
      builder: (context, Box<Receipt> box, _) {
        final expired = _receiptBox.values
            .where((r) => r.warrantyEnd.isBefore(DateTime.now()))
            .toList();
        return ExpiredReceiptsScreen(receipts: expired); // <- передаем сразу List<Receipt>
      },
    ),
    2: const ProfileScreen(),//профиль, заглушка
    3: SettingsScreen(//настройки
      themeService: widget.themeService,
      notificationsEnabled: _notificationsEnabled,
      onNotificationsChanged: (val) =>
          setState(() => _notificationsEnabled = val),
    ),
  };

  return Scaffold(
    appBar: AppBar(title: const Text("Гарантийные чеки"), centerTitle: true),
    body: pages[_selectedIndex]!,
    floatingActionButton: _buildFloatingButton(),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.receipt_outlined),
          selectedIcon: Icon(Icons.receipt),
          label: "Чеки",
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: "Истёкшие",
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: "Профиль",
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: "Настройки",
        ),
      ],
    ),
  );
}}
