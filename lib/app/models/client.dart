class Client {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? label;
  final double openingBalance;

  const Client({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.label,
    this.openingBalance = 0,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: (map['id'] as num).toInt(),
      name: (map['name'] as String?) ?? '',
      phone: map['phone']?.toString(),
      email: map['email'] as String?,
      label: map['lable'] as String?,
      openingBalance: ((map['opening_balance'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toInsert() => {
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': num.tryParse(phone!),
        if (email != null && email!.isNotEmpty) 'email': email,
        if (label != null && label!.isNotEmpty) 'lable': label,
        'opening_balance': openingBalance,
      };
}
