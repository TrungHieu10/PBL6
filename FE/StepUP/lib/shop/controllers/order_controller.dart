import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_app/shop/controllers/cart_controller.dart';
import 'package:flutter_app/shop/controllers/address_controller.dart';
import 'package:flutter_app/common/widgets/success_screen/success_screen.dart';
import 'package:flutter_app/constants/image_string.dart';
import 'package:flutter_app/navigation_menu.dart';

class OrderController extends GetxController {
  static OrderController get instance => Get.find();

  late final CartController cartController;
  late final AddressController addressController;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final isLoading = false.obs;
  final selectedPaymentMethod = 'VNPAY'.obs;

  // Chú ý: 10.0.2.2 chỉ dùng trên Android Emulator
  final String baseUrl = "http://10.0.2.2:8000/api/orders";

  @override
  void onInit() {
    super.onInit();
    cartController = Get.put(CartController());
    addressController = Get.put(AddressController());
    _initDeepLinkListener();
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print("🔗 Nhận Deep Link: $uri");
        _handlePaymentResult(uri);
      }
    }, onError: (err) {
      print("Lỗi Deep Link: $err");
    });
  }

  void _handlePaymentResult(Uri uri) {
    String status = uri.queryParameters['status'] ?? '';
    String vnpResponseCode = uri.queryParameters['vnp_ResponseCode'] ?? '';

    if (status == 'success' || vnpResponseCode == '00') {
      Get.to(() => SuccessScreen(
            image: AppImages.checkoutsuccess,
            title: 'Thanh toán thành công!',
            subTitle: 'Đơn hàng của bạn đã được xác nhận.',
            onPressed: () {
              cartController.fetchCart(); // Xóa giỏ hàng
              Get.offAll(() => const NavigationMenu());
            },
          ));
    } else if (status == 'cancelled') {
      _showError('Bạn đã hủy thanh toán.');
    } else {
      _showError('Thanh toán thất bại hoặc bị lỗi.');
    }
  }

  Future<void> processOrder() async {
  if (cartController.selectedItems.isEmpty) {
    _showError('Vui lòng chọn sản phẩm');
    return;
  }

  isLoading.value = true;

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showError('Bạn chưa đăng nhập');
      return;
    }

    final body = {
      "items": cartController.selectedItems
          .map((item) => {"variant_id": item.productId, "quantity": item.quantity})
          .toList(),
      "address_id": addressController.selectedAddress.value!.id,
      "payment_method": selectedPaymentMethod.value,
      "return_url_scheme": "myapp://payment-return"
    };

    // Gọi backend
    final response = await http.post(
      Uri.parse('$baseUrl/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final paymentUrl = data['payment_url']; // có thể null với COD

      if (selectedPaymentMethod.value.toLowerCase() == 'cod') {
        // COD → show success ngay
        Get.to(() => SuccessScreen(
              image: AppImages.checkoutsuccess,
              title: 'Đặt hàng thành công',
              subTitle: 'Đơn hàng COD đã được tạo.',
              onPressed: () {
                cartController.fetchCart();
                Get.offAll(() => const NavigationMenu());
              },
            ));
      } else if (paymentUrl != null && paymentUrl.isNotEmpty) {
        // VNPAY / PayPal → mở trình duyệt ngoài
        final uri = Uri.parse(paymentUrl);
        bool launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!launched) _showError('Không thể mở trình duyệt thanh toán.');
      } else {
        _showError('Không tìm thấy liên kết thanh toán.');
      }
    } else {
      _showError('Lỗi server: ${response.body}');
    }
  } catch (e) {
    print("Lỗi processOrder: $e");
    _showError('Có lỗi xảy ra khi xử lý đơn hàng');
  } finally {
    isLoading.value = false;
  }
}

  void _showError(String message) {
  Get.rawSnackbar(
    message: message,
    backgroundColor: Colors.red,
    duration: Duration(seconds: 3),
    snackPosition: SnackPosition.BOTTOM,
  );
}
}
