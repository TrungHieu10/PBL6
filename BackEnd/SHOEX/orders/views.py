from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from decimal import Decimal # Import Decimal để tính tiền

from .models import Order, SubOrder, OrderItem
from .serializers import OrderSerializer
from cart.models import Cart
from address.models import Address


@method_decorator(csrf_exempt, name='dispatch')
class OrderViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = OrderSerializer

    def get_queryset(self):
        return Order.objects.filter(buyer=self.request.user).order_by('-created_at')

    @action(detail=False, methods=['post'])
    def create_order(self, request):
        address_id = request.data.get('address_id')
        payment_method = request.data.get('payment_method', 'COD')
        user = request.user

        if not address_id:
            return Response({'error': 'Vui lòng chọn địa chỉ'}, status=400)
        
        # 1. Lấy địa chỉ (Từ app address)
        try:
            # Chú ý: Address ở đây là model import từ address.models
            address = Address.objects.get(address_id=address_id, user=user)
        except Address.DoesNotExist:
            return Response({'error': 'Địa chỉ không hợp lệ'}, status=400)

        # 2. Lấy giỏ hàng
        try:
            cart = Cart.objects.get(user=user)
            cart_items = cart.items.all()
            if not cart_items.exists():
                return Response({'error': 'Giỏ hàng trống'}, status=400)
        except Cart.DoesNotExist:
            return Response({'error': 'Giỏ hàng trống'}, status=400)

        # 3. Transaction
        try:
            with transaction.atomic():
                order = Order.objects.create(
                    buyer=user,
                    address=address, # Gán instance Address vào
                    payment_method=payment_method,
                    total_amount=0,
                    status='pending'
                )

                total_order_amount = Decimal(0)
                
                # Nhóm theo Seller
                seller_items = {} 
                for item in cart_items:
                    seller = item.variant.product.seller
                    if seller not in seller_items: seller_items[seller] = []
                    seller_items[seller].append(item)

                for seller, items in seller_items.items():
                    sub_total = sum(item.subtotal for item in items)
                    
                    sub_order = SubOrder.objects.create(
                        order=order,
                        seller=seller,
                        total_amount=sub_total,
                        status='pending'
                    )
                    
                    for item in items:
                        OrderItem.objects.create(
                            order=order,
                            sub_order=sub_order,
                            variant=item.variant,
                            quantity=item.quantity,
                            price_at_order=item.unit_price
                        )
                    
                    total_order_amount += sub_total

                order.total_amount = total_order_amount
                order.save()

                # Xóa giỏ hàng
                cart.items.all().delete()

                # Tạo link thanh toán (Giả lập hoặc gọi SDK)
                payment_url = ""
                if payment_method == "VNPAY":
                        payment_url = request.build_absolute_uri(f"/payments/vnpay/{order.order_id}/")
                elif payment_method == "PAYPAL":
                        payment_url = request.build_absolute_uri(f"/payments/paypal/{order.order_id}/")
                return Response({
                    'message': 'Đặt hàng thành công',
                    'order_id': order.order_id,
                    'payment_url': payment_url
                }, status=status.HTTP_201_CREATED)

        except Exception as e:
            print(f"Lỗi tạo đơn: {e}")
            return Response({'error': str(e)}, status=500)
