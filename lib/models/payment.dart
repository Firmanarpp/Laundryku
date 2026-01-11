class Payment {
  final String id;
  final String orderId;
  final double amount;
  final String paymentMethod;
  final DateTime paidDate;

  Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.paidDate,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? '',
      paidDate: json['paid_date'] != null 
          ? DateTime.parse(json['paid_date']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'payment_method': paymentMethod,
      'paid_date': paidDate.toIso8601String(),
    };
  }
}
