from rest_framework import serializers
from .models import Order, SubOrder, OrderItem
from address.serializers import AddressSerializer

class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='variant.product.name', read_only=True)
    attributes = serializers.JSONField(source='variant.option_combinations', read_only=True)

    class Meta:
        model = OrderItem
        fields = ['order_item_id', 'product_name', 'quantity', 'price_at_order', 'attributes']

class SubOrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    seller_name = serializers.CharField(source='seller.store_name', default="Shop", read_only=True)

    class Meta:
        model = SubOrder
        fields = ['sub_order_id', 'seller_name', 'total_amount', 'status', 'items']

class OrderSerializer(serializers.ModelSerializer):
    sub_orders = SubOrderSerializer(many=True, read_only=True)
    # Hiển thị chi tiết địa chỉ thay vì chỉ ID
    address = AddressSerializer(read_only=True) 
    
    class Meta:
        model = Order
        fields = ['order_id', 'total_amount', 'status', 'payment_method', 'created_at', 'address', 'sub_orders']