import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/food_item.dart';
import 'models/order_plan.dart';
import 'models/plan_item.dart';
import 'repositories/food_repository.dart';
import 'repositories/order_plan_repository.dart';
import 'widgets/plan_summary_card.dart';

/// Bootstraps the Food Planner application.
void main() {
  runApp(const FoodPlannerApp());
}

/// Root widget defining app theme and home.
class FoodPlannerApp extends StatelessWidget {
  /// Builds the app with theme data.
  const FoodPlannerApp({super.key});

  /// Builds the material app shell.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Ordering Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const OrderPlannerPage(),
    );
  }
}

/// Primary screen for creating and querying daily plans.
class OrderPlannerPage extends StatefulWidget {
  /// Builds the planner page widget.
  const OrderPlannerPage({super.key});

  /// Creates the planner page state.
  @override
  State<OrderPlannerPage> createState() => _OrderPlannerPageState();
}

/// State handling selection, persistence, and UI updates.
class _OrderPlannerPageState extends State<OrderPlannerPage> {
  /// Repository used for menu actions.
  final FoodRepository _foodRepository = FoodRepository();

  /// Repository used for plan actions.
  final OrderPlanRepository _planRepository = OrderPlanRepository();

  /// Tracks currently selected date.
  DateTime _selectedDate = DateTime.now();

  /// Tracks the budget target for the day.
  double _targetCost = 30.0;

  /// Cached list of menu options.
  List<FoodItem> _menu = [];

  /// Quantities chosen per food id.
  final Map<int, int> _selections = {};

  /// Currently loaded plan for display.
  OrderPlan? _loadedPlan;

  /// Indicates whether the UI is loading.
  bool _loading = true;

  /// Stores transient status messaging.
  String? _statusMessage;

  /// Controller for the target cost text field.
  final TextEditingController _targetController = TextEditingController();

  /// Initializes database content and UI data.
  @override
  void initState() {
    super.initState();
    _targetController.text = _targetCost.toStringAsFixed(2);
    _loadMenu();
  }

  /// Cleans up controllers on widget disposal.
  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  /// Loads menu entries from the repository.
  Future<void> _loadMenu() async {
    final items = await _foodRepository.loadMenu();
    setState(() {
      _menu = items;
      _loading = false;
    });
  }

  /// Handles increasing or decreasing a selection.
  void _updateQuantity(FoodItem item, int delta) {
    final current = _selections[item.id] ?? 0;
    final newQuantity = (current + delta).clamp(0, 99);

    final prospectiveTotal = _currentTotal() +
        ((newQuantity - current) * item.price);

    if (prospectiveTotal > _targetCost + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target exceeded. Adjust items to stay under \$${_targetCost.toStringAsFixed(2)}'),
        ),
      );
      return;
    }

    setState(() {
      if (newQuantity == 0) {
        _selections.remove(item.id);
      } else {
        _selections[item.id!] = newQuantity;
      }
    });
  }

  /// Calculates the current total based on selections.
  double _currentTotal() {
    double total = 0;
    for (final item in _menu) {
      final qty = _selections[item.id] ?? 0;
      total += item.price * qty;
    }
    return total;
  }

  /// Prompts the user to pick a date for planning.
  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (chosen != null) {
      setState(() {
        _selectedDate = chosen;
      });
    }
  }

  /// Saves the composed plan into the repository.
  Future<void> _savePlan() async {
    if (_selections.isEmpty) {
      setState(() => _statusMessage = 'Pick at least one item before saving.');
      return;
    }

    final selectedItems = _selections.entries.map((entry) {
      final item = _menu.firstWhere((f) => f.id == entry.key);
      return PlanItem(item: item, quantity: entry.value);
    }).toList();

    final plan = OrderPlan(
      date: _selectedDate,
      targetCost: _targetCost,
      items: selectedItems,
    );

    await _planRepository.savePlan(plan);
    setState(() {
      _statusMessage = 'Plan saved for ${DateFormat.yMMMd().format(_selectedDate)}';
      _loadedPlan = plan;
    });
  }

  /// Loads a plan for the selected date if present.
  Future<void> _loadPlanForDate() async {
    final plan = await _planRepository.loadPlan(_selectedDate);
    if (plan == null) {
      setState(() {
        _statusMessage = 'No plan found for ${DateFormat.yMMMd().format(_selectedDate)}';
        _loadedPlan = null;
        _selections.clear();
      });
      return;
    }

    setState(() {
      _loadedPlan = plan;
      _targetCost = plan.targetCost;
      _targetController.text = plan.targetCost.toStringAsFixed(2);
      _selections
        ..clear()
        ..addEntries(plan.items.map((e) => MapEntry(e.item.id!, e.quantity)));
      _statusMessage = 'Loaded plan for ${DateFormat.yMMMd().format(_selectedDate)}';
    });
  }

  /// Presents a dialog to add or edit a food item.
  Future<void> _showFoodEditor({FoodItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final priceController = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Food Item' : 'Update Food Item',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0;
                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid name and price.')),
                      );
                      return;
                    }

                    if (existing == null) {
                      await _foodRepository.addFood(FoodItem(name: name, price: price));
                    } else {
                      await _foodRepository
                          .updateFood(existing.copyWith(name: name, price: price));
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                      _loadMenu();
                    }
                  },
                  child: Text(existing == null ? 'Add Item' : 'Update Item'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Deletes a food item and updates the list.
  Future<void> _deleteFood(FoodItem item) async {
    if (item.id == null) return;
    await _foodRepository.removeFood(item.id!);
    setState(() {
      _selections.remove(item.id);
    });
    _loadMenu();
  }

  /// Builds the main scaffold with all controls.
  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMd();
    final total = _currentTotal();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFee9ca7), Color(0xFFffdde1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Planner',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Plan meals and stay on budget',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadMenu,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date'),
                                  Text(
                                    formatter.format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _pickDate,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target cost per day'),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _targetController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      prefixText: '\$',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      final parsed = double.tryParse(value) ?? _targetCost;
                                      setState(() {
                                        _targetCost = parsed;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Current total'),
                                Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: total > _targetCost
                                        ? Colors.redAccent
                                        : Colors.green.shade700,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _savePlan,
                                child: const Text('Save order plan'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loadPlanForDate,
                                child: const Text('Load plan for date'),
                              ),
                            ),
                          ],
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _menu.length,
                              itemBuilder: (context, index) {
                                final item = _menu[index];
                                final quantity = _selections[item.id] ?? 0;
                                return Dismissible(
                                  key: ValueKey(item.id ?? item.name),
                                  background: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  secondaryBackground: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    await _deleteFood(item);
                                    return true;
                                  },
                                  child: ListTile(
                                    title: Text(item.name),
                                    subtitle:
                                        Text('Unit price: \$${item.price.toStringAsFixed(2)}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () => _updateQuantity(item, -1),
                                        ),
                                        Text('$quantity'),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () => _updateQuantity(item, 1),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showFoodEditor(existing: item);
                                            } else if (value == 'delete') {
                                              _deleteFood(item);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (_loadedPlan != null) PlanSummaryCard(plan: _loadedPlan!),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFoodEditor(),
        label: const Text('Add food'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
