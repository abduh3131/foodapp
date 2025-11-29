import '../data/database_helper.dart';
import '../models/order_plan.dart';

/// Provides a clean API for order plan storage.
class OrderPlanRepository {
  /// Shared database helper reference.
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Saves or replaces a plan for a date.
  Future<void> savePlan(OrderPlan plan) {
    return _databaseHelper.saveOrderPlan(plan);
  }

  /// Loads a plan for a specific date.
  Future<OrderPlan?> loadPlan(DateTime date) {
    return _databaseHelper.fetchPlanByDate(date);
  }

  /// Deletes a stored plan by id.
  Future<void> removePlan(int id) {
    return _databaseHelper.deletePlan(id);
  }
}
