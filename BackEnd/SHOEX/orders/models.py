from django.db import models
from django.conf import settings
# ✅ IMPORT MODEL TỪ APP ADDRESS
from address.models import Address 

class Order(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Chờ thanh toán'),
        ('paid', 'Đã thanh toán'),
        ('shipped', 'Đang giao'),
        ('completed', 'Hoàn thành'),
        ('cancelled', 'Đã hủy'),
    ]

    order_id = models.AutoField(primary_key=True, verbose_name="Mã đơn hàng")
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='orders',
        verbose_name="Người mua"
    )
    
    # ✅ LIÊN KẾT ĐÚNG MODEL
    address = models.ForeignKey(
        Address, # Trỏ tới model Address đã import
        on_delete=models.PROTECT,
        related_name='orders',
        verbose_name="Địa chỉ giao hàng"
    )
    
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    payment_method = models.CharField(max_length=20, default='COD')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    shipment_status = models.CharField(
        max_length=20, 
        default='pending',
        verbose_name="Trạng thái vận chuyển"
    )

    def __str__(self):
        return f"Order #{self.order_id} - {self.buyer.username}"

class SubOrder(models.Model):
    sub_order_id = models.AutoField(primary_key=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='sub_orders')
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sales',
        verbose_name="Người bán"
    )
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, choices=Order.STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"SubOrder #{self.sub_order_id} (Order #{self.order.order_id})"

class OrderItem(models.Model):
    order_item_id = models.AutoField(primary_key=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    sub_order = models.ForeignKey(SubOrder, on_delete=models.CASCADE, related_name='items')
    
    variant = models.ForeignKey(
        'products.ProductVariant',
        on_delete=models.PROTECT,
        verbose_name="Biến thể sản phẩm"
    )
    quantity = models.IntegerField(default=1)
    price_at_order = models.DecimalField(max_digits=12, decimal_places=2)

    def __str__(self):
        return f"{self.variant.sku} x {self.quantity}"