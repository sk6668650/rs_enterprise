import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class InvoicePdfBuilder {
  static const PdfColor _ink = PdfColor.fromInt(0xFF111827);
  static const PdfColor _subInk = PdfColor.fromInt(0xFF374151);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _rule = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _stripe = PdfColor.fromInt(0xFFF8F9FB);
  static const PdfColor _accent = PdfColor.fromInt(0xFF1F2937);

  static const String phone1 = '9213128836';
  static const String phone2 = '8851749797';
  static const String email = 'lalbabupatel267@gmail.com';

  static final NumberFormat _money =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 2);

  static String _m(double v) => _money.format(v);

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static Future<Uint8List> build({
    required Invoice invoice,
    required Client client,
    required List<InvoiceItem> items,
    double openingBalance = 0,
  }) async {
    final doc = pw.Document();

    final subtotal =
        items.fold<double>(0, (s, i) => s + i.quantity * i.price);
    final tax = items.fold<double>(
        0, (s, i) => s + (i.quantity * i.price * i.tax / 100));
    final showLedger = openingBalance.abs() > 0.009;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 56),
        build: (ctx) => [
          _header(invoice),
          pw.SizedBox(height: 26),
          _billTo(client, invoice),
          if (showLedger) ...[
            pw.SizedBox(height: 14),
            _openingBalanceBanner(openingBalance),
          ],
          pw.SizedBox(height: 22),
          _itemsTable(items),
          pw.SizedBox(height: 16),
          _totals(invoice, subtotal, tax, openingBalance),
        ],
        footer: (ctx) => _footer(),
      ),
    );

    return doc.save();
  }

  static pw.Widget _openingBalanceBanner(double opening) {
    final isReceivable = opening > 0;
    final label = isReceivable
        ? 'OPENING BALANCE (CARRIED FORWARD)'
        : 'OPENING BALANCE (ADVANCE)';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _stripe,
        border: pw.Border.all(color: _hairline, width: 0.6),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 22,
            color: isReceivable
                ? const PdfColor.fromInt(0xFF92400E)
                : const PdfColor.fromInt(0xFF065F46),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.Text(
            _m(opening.abs()),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Header ----------------

  static pw.Widget _header(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RS Enterprise',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Smart invoicing made simple',
                    style: pw.TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '#INV-${invoice.id}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: _muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 1.2, color: _accent),
        pw.SizedBox(height: 4),
        pw.Container(height: 0.4, color: _rule),
      ],
    );
  }

  static pw.Widget _statusPill(String status) {
    final s = status.toLowerCase();
    PdfColor fg;
    switch (s) {
      case 'paid':
        fg = PdfColor.fromInt(0xFF065F46);
        break;
      case 'partial':
        fg = PdfColor.fromInt(0xFF1E40AF);
        break;
      default:
        fg = PdfColor.fromInt(0xFF92400E);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: fg, width: 0.6),
      ),
      child: pw.Text(
        status.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: fg,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ---------------- Bill To + Meta ----------------

  static pw.Widget _billTo(Client client, Invoice invoice) {
    final name = client.name.isEmpty ? '-' : client.name;
    final phone =
        (client.phone == null || client.phone!.isEmpty) ? null : client.phone;
    final emailAddr =
        (client.email == null || client.email!.isEmpty) ? null : client.email;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionLabel('BILL TO'),
              pw.SizedBox(height: 8),
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (phone != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  phone,
                  style: pw.TextStyle(fontSize: 10.5, color: _subInk),
                ),
              ],
              if (emailAddr != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  emailAddr,
                  style: pw.TextStyle(fontSize: 10.5, color: _subInk),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionLabel('INVOICE DETAILS'),
              pw.SizedBox(height: 8),
              _metaRow(
                'Date',
                DateFormat('dd MMM yyyy').format(invoice.date),
              ),
              pw.SizedBox(height: 4),
              _metaRow('Invoice No.', '#INV-${invoice.id}'),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 78,
                    child: pw.Text(
                      'Status',
                      style: pw.TextStyle(fontSize: 10.5, color: _muted),
                    ),
                  ),
                  _statusPill(invoice.status),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionLabel(String text) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _rule, width: 0.6),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: _muted,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 78,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10.5, color: _muted),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10.5,
              color: _ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Items table ----------------

  static pw.Widget _itemsTable(List<InvoiceItem> items) {
    pw.Widget cell(
      String text, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        alignment: align == pw.TextAlign.center
            ? pw.Alignment.center
            : align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            color: header ? PdfColors.white : _ink,
            fontSize: header ? 9.5 : 10.5,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            letterSpacing: header ? 1 : 0,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.symmetric(
        outside: pw.BorderSide(color: _hairline, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.7),
        1: pw.FlexColumnWidth(5.5),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _accent),
          children: [
            cell('#', header: true, align: pw.TextAlign.center),
            cell('DESCRIPTION', header: true),
            cell('QTY', header: true, align: pw.TextAlign.center),
            cell('PRICE', header: true, align: pw.TextAlign.right),
            cell('TAX %', header: true, align: pw.TextAlign.center),
            cell('AMOUNT', header: true, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : _stripe,
            ),
            children: [
              cell('${i + 1}', align: pw.TextAlign.center),
              cell(
                items[i].productName.isEmpty ? '-' : items[i].productName,
              ),
              cell(_n(items[i].quantity), align: pw.TextAlign.center),
              cell(_m(items[i].price), align: pw.TextAlign.right),
              cell(_n(items[i].tax), align: pw.TextAlign.center),
              cell(_m(items[i].totalAmount), align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  // ---------------- Totals ----------------

  static pw.Widget _totals(
    Invoice invoice,
    double subtotal,
    double tax,
    double openingBalance,
  ) {
    final hasPayment = invoice.paidAmount > 0;
    final hasOpening = openingBalance.abs() > 0.009;
    final paid = invoice.paidAmount;
    final closingBalance = openingBalance + invoice.amount - paid;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Spacer(flex: 5),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _totalRow('Subtotal', _m(subtotal)),
              pw.SizedBox(height: 6),
              _totalRow('Tax', _m(tax)),
              pw.SizedBox(height: 10),
              pw.Container(height: 0.6, color: _rule),
              pw.SizedBox(height: 10),
              _totalRow(
                'INVOICE TOTAL',
                _m(invoice.amount),
                emphasis: true,
              ),
              if (hasPayment) ...[
                pw.SizedBox(height: 6),
                _totalRow('Amount Paid', _m(paid)),
              ],
              if (hasOpening) ...[
                pw.SizedBox(height: 10),
                pw.Container(height: 0.6, color: _rule),
                pw.SizedBox(height: 10),
                _totalRow(
                  openingBalance >= 0
                      ? 'Opening Balance'
                      : 'Opening (Advance)',
                  _m(openingBalance.abs()),
                ),
                pw.SizedBox(height: 6),
                _totalRow('+ This Invoice', _m(invoice.amount)),
                if (hasPayment) ...[
                  pw.SizedBox(height: 6),
                  _totalRow('- Amount Paid', _m(paid)),
                ],
                pw.SizedBox(height: 10),
                pw.Container(height: 1.4, color: _accent),
                pw.SizedBox(height: 10),
                _totalRow(
                  closingBalance >= 0
                      ? 'CLOSING BALANCE'
                      : 'CLOSING (ADVANCE)',
                  _m(closingBalance.abs()),
                  emphasis: true,
                ),
              ] else ...[
                pw.SizedBox(height: 10),
                pw.Container(height: 1.4, color: _accent),
                if (hasPayment) ...[
                  pw.SizedBox(height: 10),
                  _totalRow(
                    invoice.isPaid ? 'Paid in Full' : 'Balance Due',
                    invoice.isPaid ? _m(0) : _m(invoice.balance),
                    emphasis: true,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool emphasis = false,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasis ? 12 : 11,
              color: emphasis ? _ink : _muted,
              fontWeight:
                  emphasis ? pw.FontWeight.bold : pw.FontWeight.normal,
              letterSpacing: emphasis ? 1 : 0,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: emphasis ? 13 : 11,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------------- Footer ----------------

  static pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 0.6, color: _rule),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
            letterSpacing: 0.6,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Tel  $phone1   $phone2     Email  $email',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ],
    );
  }
}
