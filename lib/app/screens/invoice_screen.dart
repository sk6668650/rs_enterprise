import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/invoice_controller.dart';
import '../models/client.dart';
import '../models/invoice_item.dart';
import '../utils/format.dart';

class _ItemDraft {
  final productName = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final tax = TextEditingController(text: '0');

  double get total {
    final q = double.tryParse(quantity.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    final t = double.tryParse(tax.text) ?? 0;
    return InvoiceItem.computeLineTotal(quantity: q, price: p, tax: t);
  }

  bool validate() {
    if (productName.text.trim().isEmpty) return false;
    final q = double.tryParse(quantity.text);
    final p = double.tryParse(price.text);
    if (q == null || q <= 0) return false;
    if (p == null || p < 0) return false;
    return true;
  }

  InvoiceItem toModel() {
    final q = double.parse(quantity.text);
    final p = double.parse(price.text);
    final t = double.tryParse(tax.text) ?? 0;
    return InvoiceItem(
      productName: productName.text.trim(),
      quantity: q,
      price: p,
      tax: t,
      totalAmount: InvoiceItem.computeLineTotal(quantity: q, price: p, tax: t),
    );
  }

  void dispose() {
    productName.dispose();
    quantity.dispose();
    price.dispose();
    tax.dispose();
  }
}

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Client _client;
  final List<_ItemDraft> _items = [_ItemDraft()];
  DateTime _invoiceDate = DateTime.now();

  InvoiceController get _invoices => Get.find<InvoiceController>();

  @override
  void initState() {
    super.initState();
    _client = Get.arguments as Client;
    _invoiceDate =
        DateTime(_invoiceDate.year, _invoiceDate.month, _invoiceDate.day);
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ItemDraft()));

  void _removeItem(int i) {
    if (_items.length == 1) return;
    setState(() {
      _items.removeAt(i).dispose();
    });
  }

  double get _grandTotal =>
      _items.fold<double>(0, (sum, i) => sum + i.total);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _invoiceDate =
          DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_items.any((d) => !d.validate())) {
      Get.snackbar(
        'Invalid items',
        'Check that every item has a name, quantity > 0 and price.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final invoice = await _invoices.createInvoice(
      clientId: _client.id,
      items: _items.map((d) => d.toModel()).toList(),
      date: _invoiceDate,
    );
    if (invoice != null && mounted) {
      Get.back(result: invoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Invoice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(_client.name.isEmpty ? '(unnamed)' : _client.name),
                subtitle: Text(_client.phone ?? ''),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Invoice date'),
                subtitle:
                    Text(DateFormat('EEE, dd MMM yyyy').format(_invoiceDate)),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              _ItemCard(
                index: i + 1,
                draft: _items[i],
                canRemove: _items.length > 1,
                onChanged: () => setState(() {}),
                onRemove: () => _removeItem(i),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppFormat.money(_grandTotal),
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => ElevatedButton(
                  onPressed: _invoices.isSaving.value ? null : _submit,
                  child: Text(
                    _invoices.isSaving.value ? 'Saving...' : 'Save Invoice',
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final int index;
  final _ItemDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ItemCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Item #$index',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            TextFormField(
              controller: draft.productName,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Product / description',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => onChanged(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    decoration: const InputDecoration(labelText: 'Qty'),
                    validator: (v) {
                      final q = double.tryParse((v ?? '').trim());
                      if (q == null || q <= 0) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: draft.price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').trim());
                      if (p == null || p < 0) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: draft.tax,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Line total: ${AppFormat.money(draft.total)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
