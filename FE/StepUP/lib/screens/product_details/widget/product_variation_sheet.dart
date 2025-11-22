import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_app/constants/sizes.dart';
import 'package:flutter_app/constants/colors.dart';
import 'package:flutter_app/shop/models/product_model.dart';
import 'package:flutter_app/shop/controllers/cart_controller.dart';
import 'package:flutter_app/shop/controllers/product_variation_controller.dart';
import 'package:flutter_app/widgets/containers/rounded_container.dart';
import 'package:flutter_app/screens/product_details/widget/choice_chip.dart'; 
import 'package:flutter_app/features/shop/screens/cart/cart.dart';

enum SheetMode { addToCart, buyNow }

class ProductVariationSheet extends StatelessWidget {
  final ProductModel product;
  final SheetMode mode;

  const ProductVariationSheet({
    super.key,
    required this.product,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(VariationController());
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.reset());

    final availableAttributes = controller.getAvailableAttributes(product);

    // Xử lý ảnh URL cho localhost
    String imageUrl = product.image ?? "";
    if (imageUrl.startsWith("/media")) {
      imageUrl = "http://10.0.2.2:8000$imageUrl";
    }

    return Padding(
      padding: const EdgeInsets.all(AppSizes.defaultSpace),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. Header: Ảnh + Tên + Giá + SKU ---
          Row(
            children: [
              // Ảnh sản phẩm
              RoundedContainer(
                height: 80,
                width: 80,
                padding: const EdgeInsets.all(AppSizes.sm),
                bgcolor: AppColors.light,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              ),
              const SizedBox(width: AppSizes.spaceBtwItems),

              // Thông tin bên phải ảnh
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên sản phẩm
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    // Giá (Thay đổi khi chọn variant)
                    Obx(() {
                      final price = controller.selectedVariant.value?.price ?? product.price;
                      return Text(
                        '\$${price.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold
                        ),
                      );
                    }),

                    // Trạng thái kho / SKU
                    Obx(() {
                      final variant = controller.selectedVariant.value;
                      if (variant != null) {
                        return Text("SKU: ${variant.sku} (Kho: ${variant.stock})", 
                          style: Theme.of(context).textTheme.labelMedium);
                      }
                      return const Text("Vui lòng chọn phân loại", 
                          style: TextStyle(color: Colors.grey));
                    }),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: AppSizes.spaceBtwSections),

          // --- 2. DANH SÁCH THUỘC TÍNH (MÀU, SIZE) ---
          if (availableAttributes.isNotEmpty)
            ...availableAttributes.entries.map((entry) {
              final attributeName = entry.key;
              final attributeValues = entry.value.toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attributeName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSizes.spaceBtwItems / 2),
                  Obx(() => Wrap(
                    spacing: 8,
                    children: attributeValues.map((value) {
                      final isSelected = controller.selectedAttributes[attributeName] == value;
                      return MyChoiceChip(
                        text: value,
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            controller.onAttributeSelected(product, attributeName, value);
                          }
                        },
                      );
                    }).toList(),
                  )),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                ],
              );
            }).toList()
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Sản phẩm này không có tùy chọn nào."),
            ),

          const SizedBox(height: AppSizes.spaceBtwSections),

          // --- 3. Nút Action (Xử lý Buy Now / Add to Cart) ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final variant = controller.selectedVariant.value;
                
                // Kiểm tra xem người dùng đã chọn variant chưa (nếu sp có attributes)
                if (availableAttributes.isNotEmpty && variant == null) {
                  Get.snackbar(
                    'Thông báo', 
                    'Vui lòng chọn đầy đủ thuộc tính (Màu sắc/Kích thước)', 
                    snackPosition: SnackPosition.BOTTOM, 
                    backgroundColor: Colors.red.withOpacity(0.1),
                    colorText: Colors.red,
                    margin: const EdgeInsets.all(10)
                  );
                  return;
                }

                // Nếu đã chọn xong (hoặc sp không có biến thể)
                if (variant != null) {
                  final cartController = Get.put(CartController());
                  
                  // 1. Thêm vào giỏ hàng
                  cartController.addToCart(variant.id, 1);
                  
                  // 2. Đóng BottomSheet hiện tại
                  Get.back(); 

                  // 3. Điều hướng dựa trên Mode
                  if (mode == SheetMode.buyNow) {
                    // Nếu là Buy Now -> Chuyển ngay đến CartScreen
                    Get.to(() => const CartScreen()); 
                  } else {
                    // Nếu là Add to Cart -> Hiện thông báo thành công
                    Get.snackbar(
                      'Thành công', 
                      'Đã thêm sản phẩm vào giỏ hàng',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green.withOpacity(0.1),
                      colorText: Colors.green,
                      margin: const EdgeInsets.all(10)
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.all(AppSizes.md),
              ),
              child: Text(
                mode == SheetMode.buyNow ? 'Buy now' : 'Add to cart',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}