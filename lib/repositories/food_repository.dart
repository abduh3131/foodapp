import '../data/database_helper.dart';
import '../models/food_item.dart';

/// Provides a clean API for menu operations.
class FoodRepository {
  /// Shared database helper reference.
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Loads the full list of food items.
  Future<List<FoodItem>> loadMenu() {
    return _databaseHelper.fetchMenu();
  }

  /// Adds a new food item to storage.
  Future<FoodItem> addFood(FoodItem item) {
    return _databaseHelper.insertFoodItem(item);
  }

  /// Updates an existing food item.
  Future<void> updateFood(FoodItem item) {
    return _databaseHelper.updateFoodItem(item);
  }

  /// Deletes a food item by id.
  Future<void> removeFood(int id) {
    return _databaseHelper.deleteFoodItem(id);
  }
}
