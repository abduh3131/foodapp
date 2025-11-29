import 'package:flutter/material.dart';

import '../models/order_plan.dart';
import '../models/plan_item.dart';

/// Displays a saved plan summary in a modern card.
class PlanSummaryCard extends StatelessWidget {
  /// The plan to visualize.
  final OrderPlan plan;

  /// Builds the summary card widget.
  const PlanSummaryCard({super.key, required this.plan});

  /// Builds the summary layout with items and totals.
  @override
  Widget build(BuildContext context) {
    final total = plan.items.fold<double>(
      0,
      (sum, item) => sum + (item.item.price * item.quantity),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Plan for ${plan.date.toIso8601String().split('T').first}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('Target \$${plan.targetCost.toStringAsFixed(2)}'),
                  backgroundColor: Colors.deepPurple.shade50,
                  labelStyle: const TextStyle(color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.items.map((PlanItem item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.item.name),
                  trailing: Text(
                    '${item.quantity} x \$${item.item.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
