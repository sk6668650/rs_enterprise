import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import 'invoice_pdf_builder.dart';

class ShareInvoice {
  static Future<void> share({
    required Invoice invoice,
    required Client client,
    required List<InvoiceItem> items,
  }) async {
    final bytes = await InvoicePdfBuilder.build(
      invoice: invoice,
      client: client,
      items: items,
    );
    await shareBytes(bytes: bytes, invoiceId: invoice.id);
  }

  static Future<void> shareBytes({
    required Uint8List bytes,
    required int invoiceId,
  }) async {
    final file = File(
      '${Directory.systemTemp.path}/invoice_$invoiceId.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Invoice INV-$invoiceId from RS Enterprise',
        subject: 'Invoice INV-$invoiceId',
      ),
    );
  }
}
