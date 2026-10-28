class Invoice {
  final int id;
  final int clientId;
  final double amount;
  final double paidAmount;
  final double balance;
  final String status;
  final DateTime date;

  const Invoice({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    required this.date,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isPartial => status.toLowerCase() == 'partial';
  bool get isDue => !isPaid && !isPartial;

  factory Invoice.fromMap(Map<String, dynamic> map) {
    final amount = ((map['amount'] as num?) ?? 0).toDouble();
    final status = (map['status'] as String?) ?? 'due';
    final rawPaid = map['paid_amount'] as num?;
    // Backfill for legacy rows where paid_amount is null:
    // a 'paid' invoice implies fully paid, otherwise zero.
    final paid = rawPaid != null
        ? rawPaid.toDouble()
        : (status.toLowerCase() == 'paid' ? amount : 0.0);
    final rawBalance = map['balance'] as num?;
    final balance = rawBalance != null
        ? rawBalance.toDouble()
        : (amount - paid).clamp(0, double.infinity).toDouble();
    return Invoice(
      id: (map['id'] as num).toInt(),
      clientId: (map['client_id'] as num).toInt(),
      amount: amount,
      paidAmount: paid,
      balance: balance,
      status: status,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
