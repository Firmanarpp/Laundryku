class Order {
  final String id;
  final String customerId;
  final double weight;
  final String serviceType;
  final double price;
  final String status;
  final String? photoUrl;
  final bool pickupNotified;
  final DateTime? pickupDate;
  final DateTime date;
  
  // For joining with customer
  String? customerName;

  Order({
    required this.id,
    required this.customerId,
    required this.weight,
    required this.serviceType,
    required this.price,
    required this.status,
    this.photoUrl,
    this.pickupNotified = false,
    this.pickupDate,
    required this.date,
    this.customerName,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      weight: (json['weight'] ?? 0).toDouble(),
      serviceType: json['service_type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? 'terima',
      photoUrl: json['photo_url'],
      pickupNotified: json['pickup_notified'] ?? false,
      pickupDate: json['pickup_date'] != null 
          ? DateTime.parse(json['pickup_date']) 
          : null,
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      customerName: json['customers']?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'weight': weight,
      'service_type': serviceType,
      'price': price,
      'status': status,
      'photo_url': photoUrl,
      'pickup_notified': pickupNotified,
      'pickup_date': pickupDate?.toIso8601String(),
      'date': date.toIso8601String(),
    };
  }
}
