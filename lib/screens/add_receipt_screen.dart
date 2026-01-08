import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:safecheck/models/receipt.dart';
import 'package:safecheck/screens/qr_scanner_screen.dart';
import 'package:safecheck/services/receipt_api_service.dart';
import '../services/alarm_notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AddReceiptScreen extends StatefulWidget {
  const AddReceiptScreen({super.key});

  @override
  State<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends State<AddReceiptScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _priceController = TextEditingController();
  final _storeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _commentController = TextEditingController();

  XFile? _receiptImage;
  final ImagePicker _picker = ImagePicker();

  DateTime? _purchaseDate;
  DateTime? _warrantyDate;

  bool _fabMenuOpen = false;
  bool _isLoading = false;

  void _showCustomDatePicker({required bool isPurchaseDate}) {
    final initialDate = isPurchaseDate
        ? (_purchaseDate ?? DateTime.now())
        : (_warrantyDate ?? _purchaseDate ?? DateTime.now());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isPurchaseDate ? "Дата покупки" : "Гарантия до"),
        content: SizedBox(
          width: 340,
          height: 400,
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)),
            ),
            child: CalendarDatePicker(
              initialDate: initialDate,
              firstDate: DateTime(2010),
              lastDate: DateTime(2035),
              onDateChanged: (date) {
                setState(() {
                  if (isPurchaseDate) {
                    _purchaseDate = date;
                  } else {
                    _warrantyDate = date;
                  }
                });
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Выбрать"),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndFillFromFns() async {
    final qr = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (qr == null || !mounted) return;

    setState(() => _isLoading = true);
    final data = await ReceiptApiService.fetchFromQrString(qr);
    if (mounted) setState(() => _isLoading = false);

    if (data != null) {
      setState(() {
        if (data['purchaseDate'] != null) {
          _purchaseDate = data['purchaseDate'];
        }
        if (data['amount'] != null) _priceController.text = data['amount'];
        if (data['store'] != null) _storeController.text = data['store'];
        if (data['title'] != null && data['title'] != 'Покупка') {
          _titleController.text = data['title'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("Чек загружен!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Чек не найден"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image != null && mounted) {
      setState(() => _receiptImage = image);
    }
  }

  void _saveReceipt() {
    if (_formKey.currentState!.validate()) {
      final receipt = Receipt(
        title: _titleController.text.trim().isEmpty
            ? "Без названия"
            : _titleController.text.trim(),
        date: _purchaseDate ?? DateTime.now(),
        warrantyEnd:
            _warrantyDate ??
            (_purchaseDate ?? DateTime.now()).add(const Duration(days: 365)),
        price: _priceController.text,
        store: _storeController.text,
        category: _categoryController.text,
        comment: _commentController.text,
        imagePath: _receiptImage?.path ?? "",
      );
      final box = Hive.box<Receipt>('receipts');
      box.add(receipt);  //box.put(receipt.id, receipt)
      AlarmNotificationService.scheduleForReceipt(receipt);
      Navigator.pop(context, receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Новый чек"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _saveReceipt, icon: const Icon(Icons.save)),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: "Что купили?",
                      hintText: "iPhone 15, Холодильник...",
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? "Введите название" : null,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              _showCustomDatePicker(isPurchaseDate: true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Дата покупки",
                              prefixIcon: const Icon(Icons.calendar_today),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _purchaseDate != null
                                  ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(_purchaseDate!)
                                  : "Выберите",
                              style: TextStyle(
                                color: _purchaseDate != null
                                    ? null
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              _showCustomDatePicker(isPurchaseDate: false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Гарантия до",
                              prefixIcon: const Icon(Icons.verified),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _warrantyDate != null
                                  ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(_warrantyDate!)
                                  : "Выберите",
                              style: TextStyle(
                                color: _warrantyDate != null
                                    ? null
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      title: const Text(
                        "Дополнительно",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Сумма",
                            prefixIcon: Icon(Icons.price_check),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            labelText: "Магазин",
                            prefixIcon: Icon(Icons.store),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: "Категория",
                            prefixIcon: Icon(Icons.category),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: "Комментарий",
                            prefixIcon: Icon(Icons.note),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_receiptImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_receiptImage!.path),
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),

      // FAB — РОВНО ПО ПРАВОМУ КРАЮ
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _fabMenuOpen ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: FloatingActionButton.extended(
                backgroundColor: Colors.green,
                onPressed: _scanAndFillFromFns,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("QR из ФНС"),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedScale(
              scale: _fabMenuOpen ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: FloatingActionButton.extended(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Камера"),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedScale(
              scale: _fabMenuOpen ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: FloatingActionButton.extended(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("Галерея"),
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () => setState(() => _fabMenuOpen = !_fabMenuOpen),
              child: Icon(_fabMenuOpen ? Icons.close : Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
