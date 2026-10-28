class Payment {
  final int? id;
  final int? invoiceId;
  final int clientId;
  final double amount;
  final DateTime paidAt;
  final String? method;
  final String? referenceNo;
  final String? note;
  final DateTime? createdAt;

  const Payment({
    this.id,
    this.invoiceId,
    required this.clientId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.referenceNo,
    this.note,
    this.createdAt,
  });

  bool get isOnAccount => invoiceId == null;

  factory Payment.fromMap(Map<String, dynamic> map) {
    final paidAtRaw = map['paid_at'] as String?;
    final createdAtRaw = map['created_at'] as String?;
    return Payment(
      id: (map['id'] as num?)?.toInt(),
      invoiceId: (map['invoice_id'] as num?)?.toInt(),
      clientId: (map['client_id'] as num).toInt(),
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      paidAt: paidAtRaw != null
          ? _parseStoredAsLocal(paidAtRaw)
          : (createdAtRaw != null
              ? _parseStoredAsLocal(createdAtRaw)
              : DateTime.now()),
      method: map['method'] as String?,
      referenceNo: map['reference_no'] as String?,
      note: map['note'] as String?,
      createdAt: createdAtRaw != null
          ? _parseStoredAsLocal(createdAtRaw)
          : null,
    );
  }

  // We store paidAt with `toIso8601String()` which omits the offset, so
  // Postgres records the local clock time as if it were UTC. Reading it back
  // as UTC and then comparing against local-zone dates causes off-by-offset
  // bugs (a 7pm IST payment ends up "after" a same-day end-of-day boundary).
  // Strip any trailing timezone marker so the stored wall-clock time is
  // interpreted as local — the inverse of how we wrote it.
  static DateTime _parseStoredAsLocal(String iso) {
    final tz = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').firstMatch(iso);
    final stripped = tz != null ? iso.substring(0, tz.start) : iso;
    return DateTime.parse(stripped);
  }

  Map<String, dynamic> toInsert() => {
        'client_id': clientId,
        if (invoiceId != null) 'invoice_id': invoiceId,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        if (method != null && method!.trim().isNotEmpty) 'method': method,
        if (referenceNo != null && referenceNo!.trim().isNotEmpty)
          'reference_no': referenceNo,
        if (note != null && note!.trim().isNotEmpty) 'note': note,
      };
}
