import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/invoice_pdf_builder.dart';
import '../services/share_invoice.dart';

class InvoicePreviewArgs {
  final Invoice invoice;
  final Client client;
  final List<InvoiceItem> items;
  final double openingBalance;

  const InvoicePreviewArgs({
    required this.invoice,
    required this.client,
    required this.items,
    this.openingBalance = 0,
  });
}

class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({super.key});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late final InvoicePreviewArgs _args;
  late Future<Uint8List> _pdfFuture;
  Uint8List? _bytes;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _args = Get.arguments as InvoicePreviewArgs;
    _pdfFuture = _buildPdf();
  }

  Future<Uint8List> _buildPdf() async {
    final bytes = await InvoicePdfBuilder.build(
      invoice: _args.invoice,
      client: _args.client,
      items: _args.items,
      openingBalance: _args.openingBalance,
    );
    _bytes = bytes;
    return bytes;
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = _bytes ?? await _pdfFuture;
      await ShareInvoice.shareBytes(
          bytes: bytes, invoiceId: _args.invoice.id);
    } catch (e) {
      Get.snackbar('Could not share', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
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
                      child: Text('Could not generate preview\n${snap.error ?? ''}',
                          textAlign: TextAlign.center),
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
                label: const Text('Share Invoice'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
