import 'plan_item.dart';

/// Represents a saved daily order plan.
class OrderPlan {
  /// Identifier for the stored plan.
  final int? id;

  /// The date the plan applies to.
  final DateTime date;

  /// The spending limit for the day.
  final double targetCost;

  /// Collection of items chosen for the plan.
  final List<PlanItem> items;

  /// Builds a complete order plan snapshot.
  const OrderPlan({
    this.id,
    required this.date,
    required this.targetCost,
    required this.items,
  });
}
