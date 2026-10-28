import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/client_controller.dart';
import '../controllers/invoice_controller.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/payment.dart';
import '../routes/app_routes.dart';
import '../utils/format.dart';
import 'invoice_preview_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late final int _invoiceId;
  final RxList<InvoiceItem> _items = <InvoiceItem>[].obs;
  final RxList<Payment> _payments = <Payment>[].obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isLoadingPayments = false.obs;

  InvoiceController get _invoices => Get.find<InvoiceController>();
  ClientController get _clients => Get.find<ClientController>();

  @override
  void initState() {
    super.initState();
    final inv = Get.arguments as Invoice;
    _invoiceId = inv.id;
    _loadAll();
  }

  Invoice? _currentInvoice() =>
      _invoices.invoices.firstWhereOrNull((i) => i.id == _invoiceId);

  Future<void> _loadAll() async {
    await Future.wait([_loadItems(), _loadPayments()]);
  }

  Future<void> _loadItems() async {
    _isLoading.value = true;
    final fetched = await _invoices.fetchItems(_invoiceId);
    _items.assignAll(fetched);
    _isLoading.value = false;
  }

  Future<void> _loadPayments() async {
    _isLoadingPayments.value = true;
    final fetched = await _invoices.fetchPayments(_invoiceId);
    _payments.assignAll(fetched);
    _isLoadingPayments.value = false;
  }

  Client _clientFor(int clientId) =>
      _clients.clients.firstWhereOrNull((c) => c.id == clientId) ??
      Client(id: clientId, name: 'Unknown client');

  Future<void> _openPreview() async {
    final invoice = _currentInvoice();
    if (invoice == null || _items.isEmpty) {
      Get.snackbar('Not ready', 'Items are still loading.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final client = _clientFor(invoice.clientId);

    // Pull this client's full payment history so we can compute what they
    // owed BEFORE this invoice and stamp it on the PDF as opening balance.
    final allPayments = await _invoices.fetchPaymentsForClient(client.id);
    final billed = _invoices.invoices
        .where((i) => i.clientId == client.id)
        .fold<double>(0, (s, i) => s + i.amount);
    final received = allPayments.fold<double>(0, (s, p) => s + p.amount);
    final netOutstanding = client.openingBalance + billed - received;
    final previousOutstanding = netOutstanding - invoice.balance;

    Get.toNamed(
      Routes.invoicePreview,
      arguments: InvoicePreviewArgs(
        invoice: invoice,
        client: client,
        items: List<InvoiceItem>.from(_items),
        openingBalance: previousOutstanding,
      ),
    );
  }

  Future<void> _openReceivePaymentDialog() async {
    final invoice = _currentInvoice();
    if (invoice == null || invoice.balance <= 0) return;
    final result = await showDialog<_PaymentDialogResult>(
      context: context,
      builder: (_) => _ReceivePaymentDialog(invoice: invoice),
    );
    if (result == null) return;
    final ok = await _invoices.recordPayment(
      invoiceId: invoice.id,
      amount: result.amount,
      method: result.method,
      referenceNo: result.referenceNo,
      note: result.note,
      paidAt: result.paidAt,
    );
    if (ok) await _loadPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('INV-$_invoiceId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Preview & Share',
            onPressed: _openPreview,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: Obx(() {
          final invoice = _currentInvoice();
          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }
          final client = _clientFor(invoice.clientId);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name.isEmpty ? '(unnamed)' : client.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEE, dd MMM yyyy').format(invoice.date),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(height: 20),
                      _row('Total', AppFormat.money(invoice.amount)),
                      _row('Paid', AppFormat.money(invoice.paidAmount)),
                      _row(
                        'Balance',
                        AppFormat.money(invoice.balance),
                        bold: true,
                        color: invoice.balance > 0
                            ? Colors.orange
                            : Colors.green,
                      ),
                      _row('Status', invoice.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Header('Items'),
              if (_isLoading.value && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No items found.'),
                )
              else
                ..._items.map((item) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(item.productName.isEmpty
                            ? '(no name)'
                            : item.productName),
                        subtitle: Text(
                          'Qty ${item.quantity} × ${AppFormat.money(item.price)}'
                          '${item.tax > 0 ? '  ·  Tax ${item.tax}%' : ''}',
                        ),
                        trailing: Text(
                          AppFormat.money(item.totalAmount),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )),
              const SizedBox(height: 16),
              const _Header('Payments'),
              if (_isLoadingPayments.value && _payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No payments yet.'),
                )
              else
                ..._payments.map((p) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(AppFormat.money(p.amount)),
                        subtitle: Text(_paymentSubtitle(p)),
                      ),
                    )),
              const SizedBox(height: 24),
              if (invoice.balance > 0)
                Obx(() => ElevatedButton.icon(
                      onPressed: _invoices.isRecordingPayment.value
                          ? null
                          : _openReceivePaymentDialog,
                      icon: const Icon(Icons.payments),
                      label: const Text('Receive Payment'),
                    )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openPreview,
                icon: const Icon(Icons.share),
                label: const Text('Preview & Share'),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentSubtitle(Payment p) {
    final parts = <String>[
      DateFormat('MMM d, yyyy').format(p.paidAt),
      if ((p.method ?? '').isNotEmpty) p.method!,
      if ((p.referenceNo ?? '').isNotEmpty) 'Ref: ${p.referenceNo}',
    ];
    return parts.join(' · ');
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaymentDialogResult {
  final double amount;
  final String? method;
  final String? referenceNo;
  final String? note;
  final DateTime paidAt;
  const _PaymentDialogResult({
    required this.amount,
    required this.paidAt,
    this.method,
    this.referenceNo,
    this.note,
  });
}

class _ReceivePaymentDialog extends StatefulWidget {
  final Invoice invoice;
  const _ReceivePaymentDialog({required this.invoice});

  @override
  State<_ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends State<_ReceivePaymentDialog> {
  static const _methods = ['Cash', 'UPI', 'Bank', 'Cheque', 'Card', 'Other'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'Cash';
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.invoice.balance.toStringAsFixed(2),
    );
    _paidAt = DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _paidAt = DateTime(picked.year, picked.month, picked.day,
            _paidAt.hour, _paidAt.minute);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountCtrl.text.trim());
    Navigator.of(context).pop(_PaymentDialogResult(
      amount: amount,
      paidAt: _paidAt,
      method: _method,
      referenceNo:
          _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.invoice.balance;
    return AlertDialog(
      title: Text('Receive on INV-${widget.invoice.id}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Balance: ${AppFormat.money(balance)}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return 'Enter an amount';
                  final value = double.tryParse(raw);
                  if (value == null) return 'Invalid number';
                  if (value <= 0) return 'Must be greater than zero';
                  if (value - balance > 0.009) {
                    return 'Cannot exceed balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _method,
                items: _methods
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v ?? 'Cash'),
                decoration: const InputDecoration(
                  labelText: 'Method',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Paid on',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(DateFormat('MMM d, yyyy').format(_paidAt)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference No. (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Receive'),
        ),
      ],
    );
  }
}
