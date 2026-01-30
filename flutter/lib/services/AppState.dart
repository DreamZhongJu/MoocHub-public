import 'package:flutter/material.dart';
import 'package:flutter_jdshop/model/ProductModel.dart';
import 'package:flutter_jdshop/model/CateModle.dart';

class AppState with ChangeNotifier {
  List<ProductModel> _products = [];
  List<CateItemModel> _categories = [];
  List<dynamic> _cartItems = [];
  Map<String, dynamic> _userData = {};
  bool _isLoading = false;
  String? _error;

  List<ProductModel> get products => _products;
  List<CateItemModel> get categories => _categories;
  List<dynamic> get cartItems => _cartItems;
  Map<String, dynamic> get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setProducts(List<ProductModel> products) {
    _products = products;
    notifyListeners();
  }

  void setCategories(List<CateItemModel> categories) {
    _categories = categories;
    notifyListeners();
  }

  void setCartItems(List<dynamic> cartItems) {
    _cartItems = cartItems;
    notifyListeners();
  }

  void addToCart(dynamic item) {
    _cartItems.add(item);
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateCartItem(int index, dynamic item) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = item;
      notifyListeners();
    }
  }

  void setUserData(Map<String, dynamic> userData) {
    _userData = userData;
    notifyListeners();
  }

  void clearUserData() {
    _userData = {};
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ProductModel? getProductById(int id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  CateItemModel? getCategoryById(int id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  int get cartItemCount => _cartItems.length;

  double get cartTotalPrice {
    double total = 0;
    for (var item in _cartItems) {
      if (item is Map<String, dynamic>) {
        final price = item['price'] ?? 0;
        final quantity = item['quantity'] ?? 1;
        total += (price * quantity);
      }
    }
    return total;
  }

  bool get isLoggedIn => _userData.isNotEmpty && _userData['token'] != null;
}
