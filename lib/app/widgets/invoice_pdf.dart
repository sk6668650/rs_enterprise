import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/format.dart';

class InvoicePdf extends StatelessWidget {
  final Invoice invoice;
  final Client client;
  final List<InvoiceItem> items;

  static const String _phone1 = '9213128836';
  static const String _phone2 = '8851749797';
  static const String _email = 'lalbabupatel267@gmail.com';

  static const Color _ink = Color(0xFF000000);
  static const Color _muted = Color(0xFF555555);
  static const Color _line = Color(0xFF000000);
  static const Color _stripe = Color(0xFFF4F4F4);

  const InvoicePdf({
    super.key,
    required this.invoice,
    required this.client,
    required this.items,
  });

  double get _subtotal => items.fold(0, (s, i) => s + (i.quantity * i.price));

  double get _taxTotal =>
      items.fold(0, (s, i) => s + (i.quantity * i.price * i.tax / 100));

  double get _grandTotal => _subtotal + _taxTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(invoice: invoice),
          const SizedBox(height: 24),
          const _Divider(thick: true),
          const SizedBox(height: 18),
          _BillTo(client: client, invoice: invoice),
          const SizedBox(height: 20),
          _ItemsTable(items: items),
          const SizedBox(height: 16),
          _Totals(subtotal: _subtotal, tax: _taxTotal, total: _grandTotal),
          const SizedBox(height: 32),
          const _Divider(thick: true),
          const SizedBox(height: 12),
          _Footer(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Invoice invoice;
  const _Header({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RS Enterprise',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MetaPair(label: 'No.', value: 'INV-${invoice.id}'),
            const SizedBox(height: 2),
            _MetaPair(
              label: 'Date',
              value: DateFormat('dd MMM yyyy').format(invoice.date),
            ),
            const SizedBox(height: 2),
            _MetaPair(label: 'Status', value: invoice.status.toUpperCase()),
          ],
        ),
      ],
    );
  }
}

class _MetaPair extends StatelessWidget {
  final String label;
  final String value;
  const _MetaPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: InvoicePdf._muted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: InvoicePdf._ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BillTo extends StatelessWidget {
  final Client client;
  final Invoice invoice;
  const _BillTo({required this.client, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final name = client.name.isEmpty ? '—' : client.name;
    final phone = (client.phone == null || client.phone!.isEmpty)
        ? null
        : client.phone;
    final email = (client.email == null || client.email!.isEmpty)
        ? null
        : client.email;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BILL TO',
                style: TextStyle(
                  color: InvoicePdf._muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  color: InvoicePdf._ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Phone: $phone',
                    style: const TextStyle(
                      color: InvoicePdf._ink,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (email != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Email: $email',
                    style: const TextStyle(
                      color: InvoicePdf._ink,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemsTable extends StatelessWidget {
  final List<InvoiceItem> items;
  const _ItemsTable({required this.items});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: InvoicePdf._line, width: 1),
      ),
      child: Column(
        children: [
          Container(
            color: InvoicePdf._ink,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const _TableRow(
              cells: ['#', 'DESCRIPTION', 'QTY', 'PRICE', 'TAX %', 'AMOUNT'],
              isHeader: true,
            ),
          ),
          for (var i = 0; i < items.length; i++)
            Container(
              color: i.isEven ? Colors.white : InvoicePdf._stripe,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _TableRow(
                cells: [
                  '${i + 1}',
                  items[i].productName.isEmpty ? '—' : items[i].productName,
                  AppFormat.number(items[i].quantity),
                  AppFormat.money(items[i].price),
                  AppFormat.number(items[i].tax),
                  AppFormat.money(items[i].totalAmount),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  const _TableRow({required this.cells, this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    final flexes = const [1, 5, 1, 2, 1, 2];
    final aligns = const [
      TextAlign.center,
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
      TextAlign.center,
      TextAlign.right,
    ];
    final style = isHeader
        ? const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          )
        : const TextStyle(
            color: InvoicePdf._ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: flexes[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(cells[i], textAlign: aligns[i], style: style),
            ),
          ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  final double subtotal;
  final double tax;
  final double total;

  const _Totals({
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(flex: 3),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _TotalRow(label: 'Subtotal', value: AppFormat.money(subtotal)),
              const SizedBox(height: 4),
              _TotalRow(label: 'Tax', value: AppFormat.money(tax)),
              const SizedBox(height: 8),
              const _Divider(thick: false),
              const SizedBox(height: 8),
              _TotalRow(
                label: 'TOTAL',
                value: AppFormat.money(total),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? const TextStyle(
            color: InvoicePdf._ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          )
        : const TextStyle(
            color: InvoicePdf._ink,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool thick;
  const _Divider({required this.thick});

  @override
  Widget build(BuildContext context) {
    return Container(height: thick ? 1.4 : 0.8, color: InvoicePdf._line);
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Thank you for your business.',
          style: TextStyle(
            color: InvoicePdf._ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: const [
              _FooterItem(icon: Icons.call_outlined, text: InvoicePdf._phone1),
              _FooterItem(icon: Icons.call_outlined, text: InvoicePdf._phone2),
              _FooterItem(
                icon: Icons.mail_outline_rounded,
                text: InvoicePdf._email,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: InvoicePdf._ink),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: InvoicePdf._ink,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
