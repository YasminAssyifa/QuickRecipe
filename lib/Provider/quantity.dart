import 'package:flutter/material.dart';

class QuantityProvider extends ChangeNotifier {
  int _currentNumber = 1;
  List<double> _baseIngredientAmounts = [];
  int get currentnumber => _currentNumber;
  // set initial ingredients amounts
  void setBaseIngredientsAmount(List<double> amounts) {
    _baseIngredientAmounts = amounts;
  }

  // update ingredients based on quantity set
  List<String> get updateIngredientAmounts {
    return _baseIngredientAmounts
        .map<String>((amount) => (amount * _currentNumber).toStringAsFixed(0))
        .toList();
  }

  // increase servings
  void increaseQuantity() {
    _currentNumber++;
    notifyListeners();
  }

  //decrease servings
  void decreaseQuantity() {
    if (_currentNumber > 1) {
      _currentNumber--;
      notifyListeners();
    }
  }
}
