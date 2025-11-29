import 'food_item.dart';

/// Represents a selected item and quantity inside an order plan.
class PlanItem {
  /// The chosen menu item.
  final FoodItem item;

  /// Quantity of the chosen item.
  final int quantity;

  /// Builds a plan item pairing an entry with quantity.
  const PlanItem({required this.item, required this.quantity});
}
