import 'package:flutter/material.dart';
import 'package:flutter_app/shop/models/order_model.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Order #${order.id}"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusSection(context),
          const SizedBox(height: 20),
          _buildAddressSection(context),
          const SizedBox(height: 20),
          _buildPaymentSection(context),
          const SizedBox(height: 20),
          _buildItemsSection(context),
          const SizedBox(height: 20),
          _buildTotalSection(context),
        ],
      ),
    );
  }

  // -----------------------
  // 1. ORDER STATUS
  // -----------------------
  Widget _buildStatusSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Iconsax.truck_fast, "Order Status"),
            const SizedBox(height: 10),
            _infoRow("Shipping Status", order.orderStatusText),
            _infoRow("Payment Status", order.paymentStatusText),
            _infoRow("Created At", order.formattedOrderDate),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // 2. ADDRESS SECTION — FIXED
  // -----------------------
  Widget _buildAddressSection(BuildContext context) {
    final addr = order.address;

    if (addr == null) {
      return const SizedBox(); // Không có địa chỉ → không hiển thị
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Iconsax.location, "Shipping Address"),
            const SizedBox(height: 10),

            // Tên người nhận
            Text(addr.name,
                style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 4),

            // Số điện thoại
            Text(addr.phoneNumber),

            const SizedBox(height: 4),

            // Full address – từ getter AddressModel
            Text(addr.fullAddress, softWrap: true),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // 3. PAYMENT SECTION
  // -----------------------
  Widget _buildPaymentSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Iconsax.card, "Payment Method"),
            const SizedBox(height: 10),

            Text(order.paymentMethod, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // 4. ITEMS LIST
  // -----------------------
  Widget _buildItemsSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Iconsax.bag_2, "Items"),
            const SizedBox(height: 12),

            ...order.items.map((item) => Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    "Qty: ${item.quantity}   •   Price: \$${item.priceAtOrder}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Divider(),
              ],
            ))
          ],
        ),
      ),
    );
  }

  // -----------------------
  // 5. TOTAL SUMMARY
  // -----------------------
  Widget _buildTotalSection(BuildContext context) {
    double shippingFee = 2.0; // ví dụ nếu bạn muốn thêm ship
    double total = order.totalAmount + shippingFee;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Iconsax.money, "Order Summary"),
            const SizedBox(height: 10),

            _infoRow("Subtotal", "\$${order.totalAmount.toStringAsFixed(0)}"),
            _infoRow("Shipping Fee", "\$${shippingFee.toStringAsFixed(0)}"),
            const Divider(),
            _infoRow("Total", "\$${total.toStringAsFixed(0)}", bold: true),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // WIDGET HELPERS
  // -----------------------
  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }
}
