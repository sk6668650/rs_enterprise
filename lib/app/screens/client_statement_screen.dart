import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../controllers/invoice_controller.dart';
import '../models/client.dart';
import '../models/invoice_item.dart';
import '../models/payment.dart';
import '../services/statement_pdf_builder.dart';

class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({super.key});

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  late final Client _client;
  final InvoiceController _invoices = Get.find<InvoiceController>();

  late DateTime _fromDate;
  late DateTime _toDate;

  Future<StatementData>? _dataFuture;
  Future<Uint8List>? _pdfFuture;
  Uint8List? _bytes;
  bool _isSharing = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _client = Get.arguments as Client;
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month - 2, 1);
    _toDate = _dateOnly(now);
    _rebuild();
  }

  void _rebuild() {
    _bytes = null;
    _dataFuture = _loadData();
    _pdfFuture = _dataFuture!.then((d) async {
      final bytes = await StatementPdfBuilder.build(d);
      _bytes = bytes;
      return bytes;
    });
    setState(() {});
  }

  Future<StatementData> _loadData() async {
    final clientInvoices = _invoices.invoices
        .where((i) => i.clientId == _client.id)
        .toList();
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    final inRangeIds = clientInvoices
        .where((i) =>
            !i.date.isBefore(_fromDate) && !i.date.isAfter(to))
        .map((i) => i.id)
        .toList();
    final results = await Future.wait([
      _invoices.fetchPaymentsForClient(_client.id),
      _invoices.fetchItemsForInvoiceIds(inRangeIds),
    ]);
    final payments = results[0] as List<Payment>;
    final itemsByInvoice = results[1] as Map<int, List<InvoiceItem>>;
    return StatementData.build(
      client: _client,
      invoices: clientInvoices,
      payments: payments,
      fromDate: _fromDate,
      toDate: _toDate,
      itemsByInvoice: itemsByInvoice,
    );
  }

  Future<void> _pickDateRange() async {
    final now = _dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      _fromDate = _dateOnly(picked.start);
      _toDate = _dateOnly(picked.end);
      _rebuild();
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = _bytes ?? await _pdfFuture!;
      final period =
          '${DateFormat('yyyyMMdd').format(_fromDate)}_${DateFormat('yyyyMMdd').format(_toDate)}';
      final safeName = _client.name.trim().isEmpty
          ? 'client_${_client.id}'
          : _client.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final file = File(
        '${Directory.systemTemp.path}/statement_${safeName}_$period.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Account statement for ${_client.name} (${DateFormat('dd MMM yyyy').format(_fromDate)} - ${DateFormat('dd MMM yyyy').format(_toDate)})',
          subject: 'Statement - ${_client.name}',
        ),
      );
    } catch (e) {
      Get.snackbar('Could not share', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Period'),
            subtitle: Text('${df.format(_fromDate)}  →  ${df.format(_toDate)}'),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDateRange,
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<Uint8List>(
              future: _pdfFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError || snap.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Could not generate statement\n${snap.error ?? ''}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SfPdfViewer.memory(
                  snap.data!,
                  canShowScrollHead: false,
                  canShowPaginationDialog: false,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _share,
                icon: _isSharing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: const Text('Share Statement'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
