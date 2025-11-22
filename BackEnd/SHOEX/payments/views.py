import paypalrestsdk
from django.conf import settings
from django.http import JsonResponse, HttpResponseRedirect # <--- QUAN TRỌNG
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.shortcuts import render, redirect
from .models import Payment
from orders.models import Order
import hmac, hashlib, urllib.parse, datetime

# ------------------ CUSTOM REDIRECT CLASS ------------------
# Class này cho phép redirect về app với scheme "myapp://"
class DeepLinkRedirect(HttpResponseRedirect):
    allowed_schemes = ['http', 'https', 'ftp', 'myapp']
    
    
# TỶ GIÁ
USD_RATE = 26360.00

# ------------------ CẤU HÌNH PAYPAL ------------------
paypalrestsdk.configure({
    "mode": "sandbox",
    "client_id": "AYMfGaii6aYcdm7ZJPveVFWnl20Oqcxqpo3-Lr65XqxA08awlk0rWB2pY-CBiBz69p5s3aTLY9RlOD2c",
    "client_secret": "EJk7lfd1KQHyHD2RqigyII7En7I_AWoeQ3icvUoZ3egVMCZZ-MpJDBfnUSSWPb4NhlDncGCPa9wTFnXM"
})

# ------------------ PAYPAL ------------------
def create_paypal_payment(request, order_id):
    try:
        order = Order.objects.get(order_id=order_id)
        
        total_vnd = order.total_amount
        total_usd = round(float(total_vnd) / USD_RATE, 2)
        
        if total_usd <= 0:
            return JsonResponse({"error": "Giá trị đơn hàng không hợp lệ cho thanh toán quốc tế"}, status=400)

        payment = paypalrestsdk.Payment({
            "intent": "sale",
            "payer": {"payment_method": "paypal"},
            "redirect_urls": {
                "return_url": "http://localhost:8000/payments/paypal-success",
                "cancel_url": "http://localhost:8000/payments/paypal-cancel"
            },
            "transactions": [{
                "amount": {
                    "total": str(total_usd),
                    "currency": "USD"
                },
                "description": f"Thanh toán đơn hàng {order.order_id} (Giá trị VND: {total_vnd})"
            }]
        })

        if payment.create():
            Payment.objects.update_or_create(
                order=order,
                defaults={
                    "amount": order.total_amount,
                    "payment_method": "paypal",
                    "transaction_id": payment.id,
                    "status": "pending"
                }
            )
            for link in payment.links:
                if link.rel == "approval_url":
                   # Redirect sang trang web PayPal (HTTPS) -> Dùng redirect thường
                   return redirect(link.href)
        else:
            return JsonResponse({"error": payment.error})
    except Order.DoesNotExist:
        return JsonResponse({"error": "Order not found"}, status=404)

@csrf_exempt
def paypal_success(request):
    payment_id = request.GET.get("paymentId")
    payer_id = request.GET.get("PayerID")

    if not payment_id or not payer_id:
        # Về App -> Dùng DeepLinkRedirect
        return DeepLinkRedirect("myapp://payment-return?status=error&message=MissingParams")

    payment = paypalrestsdk.Payment.find(payment_id)

    if payment.execute({"payer_id": payer_id}):
        try:
            local_payment = Payment.objects.get(transaction_id=payment_id)
            local_payment.status = "completed"
            local_payment.paid_at = timezone.now()
            local_payment.save()

            order = local_payment.order
            order.status = "completed"
            order.save()
        except Payment.DoesNotExist:
            # Về App -> Dùng DeepLinkRedirect
            return DeepLinkRedirect("myapp://payment-return?status=error&message=PaymentNotFound")

        # Về App -> Dùng DeepLinkRedirect
        return DeepLinkRedirect(f"myapp://payment-return?status=success&order_id={order.order_id}")
    else:
        # Về App -> Dùng DeepLinkRedirect
        return DeepLinkRedirect(f"myapp://payment-return?status=failed&message={payment.error}")

@csrf_exempt
def paypal_cancel(request):
    # Về App -> Dùng DeepLinkRedirect
    return DeepLinkRedirect("myapp://payment-return?status=cancelled")


# ------------------ VNPAY CONFIGURATION ------------------
NGROK_HOST = "https://successive-idella-unsparingly.ngrok-free.dev"
VNP_TMN = "OBGZ0ZPP"
VNP_SECRET = "HJAVSX9RF6QOB7WCAVRMACG52XHB43PD"
VNP_URL = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"
VNP_RETURN = f"{NGROK_HOST}/payments/vnpay-return/"
VNP_IPN_URL = f"{NGROK_HOST}/payments/vnpay-ipn/"

def _norm(v):
    return "" if v is None else str(v).strip()

def _get_vnpay_hash(data, secret_key):
    data_to_hash = {}
    for k, v in data.items():
        if k not in ["vnp_SecureHash", "vnp_SecureHashType"]:
            normalized_v = _norm(v)
            if normalized_v != "":
                data_to_hash[k] = normalized_v

    sorted_items = sorted(data_to_hash.items())
    
    hash_data_list = []
    for k, v in sorted_items:
        encoded_value = urllib.parse.quote_plus(v)
        hash_data_list.append(f"{k}={encoded_value}")

    hash_data = "&".join(hash_data_list)
    
    secure_hash = hmac.new(
        secret_key.encode('utf-8'),
        hash_data.encode('utf-8'),
        hashlib.sha512
    ).hexdigest().upper()
    
    return secure_hash

def create_vnpay_payment(request, order_id):
    try:
        order = Order.objects.get(order_id=order_id)
    except Order.DoesNotExist:
        return JsonResponse({"error": "Order not found"}, status=404)

    vnp_Amount = int(order.total_amount * 100)
    vnp_TxnRef = str(order.order_id)
    vnp_OrderInfo = f"THANH_TOAN_DON_HANG_{order.order_id}"
    vnp_CreateDate = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    vnp_ExpireDate = (datetime.datetime.now() + datetime.timedelta(minutes=15)).strftime("%Y%m%d%H%M%S")

    inputData = {
        "vnp_Version": "2.1.0",
        "vnp_Command": "pay",
        "vnp_TmnCode": VNP_TMN,
        "vnp_Amount": vnp_Amount,
        "vnp_CurrCode": "VND",
        "vnp_TxnRef": vnp_TxnRef,
        "vnp_OrderInfo": vnp_OrderInfo,
        "vnp_OrderType": "other",
        "vnp_Locale": "vn",
        "vnp_ReturnUrl": VNP_RETURN,
        "vnp_IpAddr": "127.0.0.1",
        "vnp_CreateDate": vnp_CreateDate,
        "vnp_ExpireDate": vnp_ExpireDate,
    }

    secure_hash = _get_vnpay_hash(inputData, VNP_SECRET)
    query_string = urllib.parse.urlencode(inputData, quote_via=urllib.parse.quote)
    payment_url = f"{VNP_URL}?{query_string}&vnp_SecureHashType=HMACSHA512&vnp_SecureHash={secure_hash}"

    Payment.objects.update_or_create(
        order=order,
        defaults={
            "amount": order.total_amount,
            "payment_method": "vnpay",
            "transaction_id": vnp_TxnRef,
            "status": "pending"
        }
    )
    
    # Redirect sang trang web VNPAY (HTTPS) -> Dùng redirect thường
    return redirect(payment_url)

@csrf_exempt
def vnpay_return(request):
    inputData = request.GET
    vnp_TxnRef = inputData.get("vnp_TxnRef")
    vnp_ResponseCode = inputData.get("vnp_ResponseCode")
    vnp_secure_recv = inputData.get("vnp_SecureHash", "").upper()

    secure_calc = _get_vnpay_hash(inputData, VNP_SECRET)
    
    if secure_calc != vnp_secure_recv:
        # Về App -> Dùng DeepLinkRedirect
        return DeepLinkRedirect("myapp://payment-return?status=error&message=InvalidSignature")

    try:
        payment = Payment.objects.get(order__order_id=vnp_TxnRef)
        order = payment.order
    except Payment.DoesNotExist:
        # Về App -> Dùng DeepLinkRedirect
        return DeepLinkRedirect("myapp://payment-return?status=error&message=PaymentNotFound")

    if vnp_ResponseCode == "00":
        payment.status = "completed"
        payment.paid_at = timezone.now()
        payment.save()
        order.status = "completed"
        order.save()
    else:
        payment.status = "failed"
        payment.save()

    # Về App -> Dùng DeepLinkRedirect
    deep_link = f"myapp://payment-return?vnp_ResponseCode={vnp_ResponseCode}&order_id={vnp_TxnRef}"
    return DeepLinkRedirect(deep_link)

@csrf_exempt
def vnpay_ipn(request):
    inputData = request.GET
    vnp_TxnRef = inputData.get("vnp_TxnRef")
    vnp_ResponseCode = inputData.get("vnp_ResponseCode")
    vnp_TransactionNo = inputData.get("vnp_TransactionNo")
    vnp_Amount_recv = inputData.get("vnp_Amount")
    vnp_secure_recv = inputData.get("vnp_SecureHash", "").upper()

    secure_calc = _get_vnpay_hash(inputData, VNP_SECRET)
    
    if secure_calc != vnp_secure_recv:
        return JsonResponse({'RspCode': '97', 'Message': 'Invalid Signature'})

    try:
        local_payment = Payment.objects.get(order__order_id=vnp_TxnRef)
        local_order = local_payment.order
    except Payment.DoesNotExist:
        return JsonResponse({'RspCode': '01', 'Message': 'Order not found'})

    if local_payment.status == "completed":
        return JsonResponse({'RspCode': '02', 'Message': 'Order already confirmed'})

    local_amount_vnd_str = str(int(local_order.total_amount * 100))

    if local_amount_vnd_str != vnp_Amount_recv:
        return JsonResponse({'RspCode': '04', 'Message': 'Invalid amount'})

    if vnp_ResponseCode == "00":
        local_payment.status = "completed"
        local_payment.paid_at = timezone.now()
        local_payment.transaction_id = vnp_TransactionNo
        local_payment.save()
        local_order.status = "completed"
        local_order.save()
    else:
        local_payment.status = "failed"
        local_payment.save()
        
    return JsonResponse({'RspCode': '00', 'Message': 'Confirm Success'})
