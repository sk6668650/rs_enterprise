class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final String productName;
  final double quantity;
  final double price;
  final double tax;
  final double totalAmount;

  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.tax,
    required this.totalAmount,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: (map['id'] as num?)?.toInt(),
      invoiceId: (map['invoice_id'] as num?)?.toInt(),
      productName: (map['product_name'] as String?) ?? '',
      quantity: ((map['quantity'] as num?) ?? 0).toDouble(),
      price: ((map['price'] as num?) ?? 0).toDouble(),
      tax: ((map['tax'] as num?) ?? 0).toDouble(),
      totalAmount: ((map['total_amount'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toInsert(int invoiceId) => {
        'invoice_id': invoiceId,
        'product_name': productName,
        'quantity': quantity,
        'price': price,
        'tax': tax,
        'total_amount': totalAmount,
      };

  static double computeLineTotal({
    required double quantity,
    required double price,
    required double tax,
  }) {
    final subtotal = quantity * price;
    return subtotal + (subtotal * tax / 100);
  }
}
