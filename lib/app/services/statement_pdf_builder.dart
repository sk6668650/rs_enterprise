import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/payment.dart';

class StatementEntry {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final List<InvoiceItem> items;

  const StatementEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.items = const [],
  });
}

class StatementData {
  final Client client;
  final DateTime fromDate;
  final DateTime toDate;
  final double openingBalance;
  final List<StatementEntry> entries;

  const StatementData({
    required this.client,
    required this.fromDate,
    required this.toDate,
    required this.openingBalance,
    required this.entries,
  });

  double get totalDebit => entries.fold<double>(0, (s, e) => s + e.debit);
  double get totalCredit => entries.fold<double>(0, (s, e) => s + e.credit);
  double get closingBalance => openingBalance + totalDebit - totalCredit;

  static StatementData build({
    required Client client,
    required List<Invoice> invoices,
    required List<Payment> payments,
    required DateTime fromDate,
    required DateTime toDate,
    Map<int, List<InvoiceItem>> itemsByInvoice = const {},
  }) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    double opening = client.openingBalance;
    final entries = <StatementEntry>[];

    for (final inv in invoices) {
      if (inv.date.isBefore(from)) {
        opening += inv.amount;
      } else if (!inv.date.isAfter(to)) {
        entries.add(StatementEntry(
          date: inv.date,
          description: 'Invoice INV-${inv.id}',
          debit: inv.amount,
          credit: 0,
          items: itemsByInvoice[inv.id] ?? const [],
        ));
      }
    }

    for (final p in payments) {
      if (p.paidAt.isBefore(from)) {
        opening -= p.amount;
      } else if (!p.paidAt.isAfter(to)) {
        final desc = p.invoiceId != null
            ? 'Payment for INV-${p.invoiceId}'
            : 'Payment received (on account)';
        entries.add(StatementEntry(
          date: p.paidAt,
          description: desc,
          debit: 0,
          credit: p.amount,
        ));
      }
    }

    entries.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      // invoice (debit) before payment (credit) on the same day
      return b.debit.compareTo(a.debit);
    });

    return StatementData(
      client: client,
      fromDate: from,
      toDate: DateTime(toDate.year, toDate.month, toDate.day),
      openingBalance: opening,
      entries: entries,
    );
  }
}

class StatementPdfBuilder {
  static const PdfColor _ink = PdfColor.fromInt(0xFF111827);
  static const PdfColor _subInk = PdfColor.fromInt(0xFF374151);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _rule = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _stripe = PdfColor.fromInt(0xFFF8F9FB);
  static const PdfColor _accent = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _debit = PdfColor.fromInt(0xFF92400E);
  static const PdfColor _credit = PdfColor.fromInt(0xFF065F46);

  static const String phone1 = '9213128836';
  static const String phone2 = '8851749797';
  static const String email = 'lalbabupatel267@gmail.com';

  static final NumberFormat _money =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 2);

  static String _m(double v) => _money.format(v);

  static Future<Uint8List> build(StatementData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 52),
        build: (ctx) => [
          _header(data),
          pw.SizedBox(height: 22),
          _summary(data),
          pw.SizedBox(height: 18),
          _ledger(data),
          pw.SizedBox(height: 14),
          _closing(data),
        ],
        footer: (ctx) => _footer(),
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(StatementData data) {
    final df = DateFormat('dd MMM yyyy');
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
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Account Statement',
                    style: pw.TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${df.format(data.fromDate)}  to  ${df.format(data.toDate)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 1.2, color: _accent),
        pw.SizedBox(height: 4),
        /// pw.Container(height: 0.4, color: _rule),
      ],
    );
  }

  static pw.Widget _summary(StatementData data) {
    final c = data.client;
    final phone =
        (c.phone == null || c.phone!.isEmpty) ? null : c.phone!;
    final emailAddr =
        (c.email == null || c.email!.isEmpty) ? null : c.email!;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionLabel('STATEMENT FOR'),
              pw.SizedBox(height: 6),
              pw.Text(
                c.name.isEmpty ? '-' : c.name,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (phone != null) ...[
                pw.SizedBox(height: 3),
                pw.Text(phone,
                    style: pw.TextStyle(fontSize: 10.5, color: _subInk)),
              ],
              if (emailAddr != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(emailAddr,
                    style: pw.TextStyle(fontSize: 10.5, color: _subInk)),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _stripe,
              border: pw.Border.all(color: _hairline, width: 0.6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _kvRow('Opening Balance', _m(data.openingBalance)),
                pw.SizedBox(height: 4),
                _kvRow('Total Billed', _m(data.totalDebit)),
                pw.SizedBox(height: 4),
                _kvRow('Total Received', _m(data.totalCredit)),
                pw.SizedBox(height: 6),
                pw.Container(height: 0.6, color: _rule),
                pw.SizedBox(height: 6),
                _kvRow('Closing Balance', _m(data.closingBalance),
                    emphasis: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _kvRow(String label, String value, {bool emphasis = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasis ? 11 : 10,
              color: emphasis ? _ink : _muted,
              fontWeight: emphasis ? pw.FontWeight.bold : pw.FontWeight.normal,
              letterSpacing: emphasis ? 0.4 : 0,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: emphasis ? 12 : 10.5,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
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

  static pw.Widget _ledger(StatementData data) {
    final df = DateFormat('dd MMM yyyy');

    pw.Widget cell(
      String text, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor? color,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        alignment: align == pw.TextAlign.center
            ? pw.Alignment.center
            : align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            color: color ?? (header ? PdfColors.white : _ink),
            fontSize: header ? 9 : 10,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            letterSpacing: header ? 0.8 : 0,
          ),
        ),
      );
    }

    pw.Widget particularsCell(StatementEntry e) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              e.description,
              style: pw.TextStyle(fontSize: 10, color: _ink),
            ),
            if (e.items.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              for (final item in e.items)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1),
                  child: pw.Text(
                    '${item.productName.isEmpty ? '-' : item.productName}'
                    '${_n(item.quantity)} x ${_m(item.price)}',
                    style: pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    double running = data.openingBalance;

    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _accent),
        children: [
          cell('DATE', header: true),
          cell('PARTICULARS', header: true),
          cell('DEBIT', header: true, align: pw.TextAlign.right),
          cell('CREDIT', header: true, align: pw.TextAlign.right),
          cell('BALANCE', header: true, align: pw.TextAlign.right),
        ],
      ),
    );

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _stripe),
        children: [
          cell(df.format(data.fromDate)),
          cell('Opening Balance', color: _subInk),
          cell('', align: pw.TextAlign.right),
          cell('', align: pw.TextAlign.right),
          cell(_m(running), align: pw.TextAlign.right),
        ],
      ),
    );

    for (var i = 0; i < data.entries.length; i++) {
      final e = data.entries[i];
      running += e.debit - e.credit;
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : _stripe,
          ),
          children: [
            cell(df.format(e.date)),
            particularsCell(e),
            cell(
              e.debit > 0 ? _m(e.debit) : '',
              align: pw.TextAlign.right,
              color: e.debit > 0 ? _debit : null,
            ),
            cell(
              e.credit > 0 ? _m(e.credit) : '',
              align: pw.TextAlign.right,
              color: e.credit > 0 ? _credit : null,
            ),
            cell(_m(running), align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.symmetric(
        outside: pw.BorderSide(color: _hairline, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(5.2),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FlexColumnWidth(2.4),
      },
      children: rows,
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static pw.Widget _closing(StatementData data) {
    final label = data.closingBalance > 0.009
        ? 'Closing Balance (Receivable)'
        : data.closingBalance < -0.009
            ? 'Closing Balance (Advance)'
            : 'Settled';
    return pw.Row(
      children: [
        pw.Spacer(flex: 4),
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const pw.BoxDecoration(color: _accent),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                pw.Text(
                  _m(data.closingBalance.abs()),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 0.6, color: _rule),
        pw.SizedBox(height: 8),
        pw.Text(
          'This statement is system-generated.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Tel  $phone1   $phone2     Email  $email',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ],
    );
  }
}
