import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/invoice_controller.dart';
import '../models/client.dart';
import '../models/payment.dart';
import '../routes/app_routes.dart';
import '../utils/format.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late final Client _client;
  final RxList<Payment> _payments = <Payment>[].obs;
  final RxBool _isLoadingPayments = false.obs;

  InvoiceController get _invoices => Get.find<InvoiceController>();

  @override
  void initState() {
    super.initState();
    _client = Get.arguments as Client;
    _loadPayments();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_invoices.fetchInvoices(), _loadPayments()]);
  }

  Future<void> _loadPayments() async {
    _isLoadingPayments.value = true;
    final fetched = await _invoices.fetchPaymentsForClient(_client.id);
    _payments.assignAll(fetched);
    _isLoadingPayments.value = false;
  }

  Future<void> _openReceivePaymentDialog() async {
    final result = await showDialog<_PaymentDialogResult>(
      context: context,
      builder: (_) => _ReceivePaymentDialog(clientName: _client.name),
    );
    if (result == null) return;
    final ok = await _invoices.recordClientPayment(
      clientId: _client.id,
      amount: result.amount,
      method: result.method,
      referenceNo: result.referenceNo,
      note: result.note,
      paidAt: result.paidAt,
    );
    if (ok) await _loadPayments();
  }

  void _openCreateInvoice() {
    Get.toNamed(Routes.createInvoice, arguments: _client)?.then((_) {
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client.name.isEmpty ? '(unnamed)' : _client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Statement',
            onPressed: () => Get.toNamed(
              Routes.clientStatement,
              arguments: _client,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Obx(() {
          final clientInvoices = _invoices.invoices
              .where((i) => i.clientId == _client.id)
              .toList();
          final billed =
              clientInvoices.fold<double>(0, (s, i) => s + i.amount);
          final received = _payments.fold<double>(0, (s, p) => s + p.amount);
          final net = _client.openingBalance + billed - received;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ContactSection(client: _client),
              if (_client.openingBalance.abs() > 0.009) ...[
                const SizedBox(height: 8),
                _OpeningBalanceTile(amount: _client.openingBalance),
              ],
              const SizedBox(height: 8),
              _StatsTable(
                billed: billed,
                received: received,
                net: net,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openCreateInvoice,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Invoice'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                          onPressed: _invoices.isRecordingPayment.value
                              ? null
                              : _openReceivePaymentDialog,
                          icon: const Icon(Icons.payments),
                          label: const Text('Receive Payment'),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionHeader('Invoices (${clientInvoices.length})'),
              if (clientInvoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No invoices for this client.'),
                )
              else
                ...clientInvoices.map((inv) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text('INV-${inv.id}'),
                        subtitle: Text(
                          '${DateFormat('MMM d, yyyy').format(inv.date)} · ${inv.status}',
                        ),
                        trailing: Text(
                          AppFormat.money(inv.amount),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => Get.toNamed(
                          Routes.invoiceDetail,
                          arguments: inv,
                        )?.then((_) => _refreshAll()),
                      ),
                    )),
              const SizedBox(height: 16),
              _SectionHeader('Payments (${_payments.length})'),
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
                        trailing: Text(
                          p.invoiceId != null
                              ? 'INV-${p.invoiceId}'
                              : 'On account',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )),
            ],
          );
        }),
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

class _ContactSection extends StatelessWidget {
  final Client client;
  const _ContactSection({required this.client});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      ));
    }

    addRow('Phone', client.phone);
    addRow('Email', client.email);
    addRow('Label', client.label);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ),
    );
  }
}

class _OpeningBalanceTile extends StatelessWidget {
  final double amount;
  const _OpeningBalanceTile({required this.amount});

  @override
  Widget build(BuildContext context) {
    final isReceivable = amount > 0;
    return Card(
      child: ListTile(
        leading: Icon(
          isReceivable ? Icons.history : Icons.savings,
          color: isReceivable ? Colors.orange : Colors.green,
        ),
        title: Text(
          isReceivable ? 'Old Receivable' : 'Old Advance',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isReceivable
              ? 'They owed you before the app'
              : 'Advance you held before the app',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          AppFormat.money(amount.abs()),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final double billed;
  final double received;
  final double net;
  const _StatsTable({
    required this.billed,
    required this.received,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final pending = net > 0 ? net : 0.0;
    final advance = net < 0 ? -net : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('Billed', AppFormat.money(billed)),
            _row('Received', AppFormat.money(received)),
            const Divider(),
            _row(
              advance > 0 ? 'Advance' : 'Pending',
              AppFormat.money(advance > 0 ? advance : pending),
              bold: true,
              color: advance > 0 ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
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
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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
  final String clientName;
  const _ReceivePaymentDialog({required this.clientName});

  @override
  State<_ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends State<_ReceivePaymentDialog> {
  static const _methods = ['Cash', 'UPI', 'Bank', 'Cheque', 'Card', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'Cash';
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
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
        _paidAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _paidAt.hour,
          _paidAt.minute,
        );
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
    return AlertDialog(
      title: Text('Receive from ${widget.clientName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
