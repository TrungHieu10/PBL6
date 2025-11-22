import 'package:flutter_app/shop/models/address_model.dart';
import 'package:intl/intl.dart';

class OrderItemModel {
  final String productName;
  final int quantity;
  final double priceAtOrder;

  OrderItemModel({
    required this.productName,
    required this.quantity,
    required this.priceAtOrder,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      priceAtOrder: double.tryParse(json['price_at_order'].toString()) ?? 0.0,
    );
  }
}

class OrderModel {
  final int id;
  final String status;
  final double totalAmount;
  final DateTime orderDate;
  final String paymentMethod;
  final AddressModel? address;
  final List<OrderItemModel> items; // ✅ thêm items list
  final String deliveryDate;

  OrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.orderDate,
    this.paymentMethod = 'COD',
    this.address,
    this.items = const [],
    this.deliveryDate = '',
  });

  String get formattedOrderDate {
    try {
      return DateFormat('dd MMM yyyy').format(orderDate);
    } catch (e) {
      return orderDate.toString();
    }
  }

  String get paymentStatusText {
    if (paymentMethod == "COD") return "Cash on Delivery";
    if (paymentMethod == "VNPAY") return "Paid via VNPay";
    if (paymentMethod == "PAYPAL") return "Paid via PayPal";
  return paymentMethod;
}
  String get orderStatusText {
    switch (status) {
      case 'pending':
        return 'Processing';
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipping';
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Processing';
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parse tất cả sub_orders → items thành một list duy nhất
    List<OrderItemModel> parsedItems = [];
    if (json['sub_orders'] != null) {
      for (var sub in (json['sub_orders'] as List)) {
        if (sub['items'] != null) {
          parsedItems.addAll((sub['items'] as List)
              .map((i) => OrderItemModel.fromJson(i)));
        }
      }
    }

    return OrderModel(
      id: json['order_id'],
      status: json['status'] ?? '',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      orderDate: DateTime.tryParse(json['created_at']) ?? DateTime.now(),
      paymentMethod: json['payment_method'] ?? 'COD',
      address: json['address'] != null ? AddressModel.fromJson(json['address']) : null,
      items: parsedItems,
    );
  }
}
