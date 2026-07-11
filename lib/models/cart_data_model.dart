/// Shared cart data models used by cart drawers and modals

class CartData {
  final String? note;
  final CartDiscount? discount;
  final CartCoupon? coupon;
  final List<CartFee> fees;

  CartData({this.note, this.discount, this.coupon, this.fees = const []});
}

class CartDiscount {
  final String type; // '$' or '%'
  final double value;

  CartDiscount({required this.type, required this.value});
}

class CartCoupon {
  final String code;
  final String type; // '$' or '%'
  final double discount;

  CartCoupon({required this.code, required this.type, required this.discount});
}

class CartFee {
  final String title;
  final String type; // '$' or '%'
  final double value;

  CartFee({required this.title, required this.type, required this.value});
}
