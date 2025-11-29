import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const FoodPlannerPage(),
    );
  }
}

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  Database? _db;

  // opens or creates the database
  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'food_planner.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE foods(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, price REAL)',
        );
        await db.execute(
          'CREATE TABLE plans(id INTEGER PRIMARY KEY AUTOINCREMENT, planDate TEXT, target REAL, total REAL)',
        );
        await db.execute(
          'CREATE TABLE plan_items(id INTEGER PRIMARY KEY AUTOINCREMENT, planId INTEGER, foodId INTEGER, quantity INTEGER)',
        );
      },
    );
    await _seedFoods();
    return _db!;
  }

  // seeds the food table with preferred items
  Future<void> _seedFoods() async {
    final db = await _open();
    final existing = await db.query('foods');
    if (existing.isNotEmpty) return;

    final foods = [
      {'name': 'Grilled Chicken Bowl', 'price': 9.50},
      {'name': 'Veggie Pasta', 'price': 8.75},
      {'name': 'Sushi Platter', 'price': 12.00},
      {'name': 'Avocado Toast', 'price': 6.25},
      {'name': 'Berry Smoothie', 'price': 5.00},
      {'name': 'Quinoa Salad', 'price': 7.80},
      {'name': 'Steak Wrap', 'price': 10.50},
      {'name': 'Fish Tacos', 'price': 9.20},
      {'name': 'Tomato Soup', 'price': 4.80},
      {'name': 'Caesar Salad', 'price': 6.90},
      {'name': 'Mango Lassi', 'price': 4.50},
      {'name': 'BBQ Burger', 'price': 11.00},
      {'name': 'Falafel Plate', 'price': 8.40},
      {'name': 'Chicken Biryani', 'price': 10.90},
      {'name': 'Poke Bowl', 'price': 12.50},
      {'name': 'Margherita Pizza', 'price': 9.30},
      {'name': 'Turkey Panini', 'price': 8.10},
      {'name': 'Greek Yogurt Parfait', 'price': 5.40},
      {'name': 'Chocolate Croissant', 'price': 3.90},
      {'name': 'Iced Coffee', 'price': 3.50},
    ];

    for (final food in foods) {
      await db.insert('foods', food);
    }
  }

  // loads all foods from the database
  Future<List<FoodItem>> fetchFoods() async {
    final db = await _open();
    final rows = await db.query('foods');
    return rows
        .map(
          (row) => FoodItem(
            id: row['id'] as int,
            name: row['name'] as String,
            price: (row['price'] as num).toDouble(),
          ),
        )
        .toList();
  }

  // adds a new food to the database
  Future<void> addFood(FoodItem item) async {
    final db = await _open();
    await db.insert('foods', {
      'name': item.name,
      'price': item.price,
    });
  }

  // updates a food entry
  Future<void> updateFood(FoodItem item) async {
    final db = await _open();
    await db.update(
      'foods',
      {'name': item.name, 'price': item.price},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // deletes a food entry
  Future<void> deleteFood(int id) async {
    final db = await _open();
    await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  // saves an order plan for a date
  Future<void> savePlan(
    DateTime date,
    double target,
    Map<int, int> items,
    List<FoodItem> foods,
  ) async {
    final db = await _open();
    final total = items.entries.fold<double>(
      0,
      (sum, entry) =>
          sum + foods.firstWhere((f) => f.id == entry.key).price * entry.value,
    );

    final planId = await db.insert('plans', {
      'planDate': DateFormat('yyyy-MM-dd').format(date),
      'target': target,
      'total': total,
    });

    for (final entry in items.entries) {
      await db.insert('plan_items', {
        'planId': planId,
        'foodId': entry.key,
        'quantity': entry.value,
      });
    }
  }

  // pulls an order plan by date
  Future<OrderPlan?> fetchPlan(DateTime date) async {
    final db = await _open();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final plans = await db.query(
      'plans',
      where: 'planDate = ?',
      whereArgs: [dateKey],
    );

    if (plans.isEmpty) return null;
    final planId = plans.first['id'] as int;
    final target = (plans.first['target'] as num).toDouble();
    final total = (plans.first['total'] as num).toDouble();

    final items = await db.query(
      'plan_items',
      where: 'planId = ?',
      whereArgs: [planId],
    );
    final foods = await fetchFoods();
    final mappedItems = items
        .map(
          (row) => PlanItem(
            food: foods.firstWhere((f) => f.id == (row['foodId'] as int)),
            quantity: row['quantity'] as int,
          ),
        )
        .toList();
    return OrderPlan(
      date: date,
      target: target,
      total: total,
      items: mappedItems,
    );
  }
}

class FoodItem {
  FoodItem({required this.id, required this.name, required this.price});

  final int id;
  final String name;
  final double price;
}

class PlanItem {
  PlanItem({required this.food, required this.quantity});

  final FoodItem food;
  final int quantity;
}

class OrderPlan {
  OrderPlan({
    required this.date,
    required this.target,
    required this.total,
    required this.items,
  });

  final DateTime date;
  final double target;
  final double total;
  final List<PlanItem> items;
}

class FoodPlannerPage extends StatefulWidget {
  const FoodPlannerPage({super.key});

  @override
  State<FoodPlannerPage> createState() => _FoodPlannerPageState();
}

class _FoodPlannerPageState extends State<FoodPlannerPage> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _foodPriceController = TextEditingController();

  List<FoodItem> _foods = [];
  Map<int, int> _selectedItems = {};
  DateTime _selectedDate = DateTime.now();
  OrderPlan? _queriedPlan;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  // pulls foods and refreshes UI
  Future<void> _loadFoods() async {
    final foods = await _db.fetchFoods();
    setState(() {
      _foods = foods;
    });
  }

  // handles selecting a date for the plan
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // handles adding or editing a food
  Future<void> _showFoodDialog({FoodItem? food}) async {
    if (food != null) {
      _foodNameController.text = food.name;
      _foodPriceController.text = food.price.toStringAsFixed(2);
    } else {
      _foodNameController.clear();
      _foodPriceController.clear();
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(food == null ? 'Add Food' : 'Update Food'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _foodNameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _foodPriceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _foodNameController.text.trim();
              final price = double.tryParse(_foodPriceController.text.trim()) ?? 0;
              if (name.isEmpty || price <= 0) return;

              if (food == null) {
                await _db.addFood(
                  FoodItem(id: 0, name: name, price: price),
                );
              } else {
                await _db.updateFood(
                  FoodItem(id: food.id, name: name, price: price),
                );
              }
              await _loadFoods();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // deletes a food entry and refreshes UI
  Future<void> _deleteFood(int id) async {
    await _db.deleteFood(id);
    setState(() {
      _selectedItems.remove(id);
    });
    await _loadFoods();
  }

  // calculates the current order total
  double _calculateTotal() {
    return _selectedItems.entries.fold<double>(
      0,
      (sum, entry) =>
          sum + _foods.firstWhere((f) => f.id == entry.key).price * entry.value,
    );
  }

  // saves the selected plan to the database
  Future<void> _savePlan() async {
    final target = double.tryParse(_targetController.text.trim()) ?? 0;
    if (target <= 0 || _selectedItems.isEmpty) return;
    final total = _calculateTotal();
    if (total > target) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total exceeds target by \$${(total - target).toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    await _db.savePlan(_selectedDate, target, _selectedItems, _foods);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan saved for the day')),
    );
    setState(() {
      _selectedItems = {};
    });
  }

  // pulls a saved plan for the selected date
  Future<void> _loadPlanForDate() async {
    final plan = await _db.fetchPlan(_selectedDate);
    setState(() {
      _queriedPlan = plan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMd().format(_selectedDate);
    final total = _calculateTotal();
    final target = double.tryParse(_targetController.text.trim()) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Ordering Planner'),
        actions: [
          IconButton(
            tooltip: 'Add food',
            onPressed: () => _showFoodDialog(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _db._open(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(dateLabel, total, target),
                const SizedBox(height: 16),
                _buildFoodList(total, target),
                const SizedBox(height: 16),
                _buildActionButtons(total),
                const SizedBox(height: 16),
                _buildPlanLookup(),
              ],
            ),
          );
        },
      ),
    );
  }

  // builds the top cards for date and totals
  Widget _buildHeader(String dateLabel, double total, double target) {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected date', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateLabel, style: const TextStyle(fontSize: 16)),
                      IconButton(
                        tooltip: 'Choose date',
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target per day', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 30.00',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Current total: \$${total.toStringAsFixed(2)}'),
                  if (target > 0)
                    Text(
                      total <= target
                          ? 'Within target'
                          : 'Over by \$${(total - target).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: total <= target ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // builds the list of foods with quantity controls
  Widget _buildFoodList(double total, double target) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Menu items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Refresh list',
                  onPressed: _loadFoods,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._foods.map(
              (food) {
                final quantity = _selectedItems[food.id] ?? 0;
                final isOverLimit = target > 0 && total > target;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  title: Text(food.name),
                  subtitle: Text('\$${food.price.toStringAsFixed(2)} each'),
                  trailing: SizedBox(
                    width: 170,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Edit food',
                          onPressed: () => _showFoodDialog(food: food),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete food',
                          onPressed: () => _deleteFood(food.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        _QuantityChip(
                          quantity: quantity,
                          onChanged: (value) {
                            setState(() {
                              if (value == 0) {
                                _selectedItems.remove(food.id);
                              } else {
                                _selectedItems[food.id] = value;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  leading: quantity > 0
                      ? CircleAvatar(
                          backgroundColor: Colors.teal.withOpacity(0.15),
                          child: Text('x$quantity'),
                        )
                      : null,
                  subtitleTextStyle: const TextStyle(color: Colors.black54),
                  selectedTileColor:
                      isOverLimit ? Colors.red.shade50 : Colors.green.shade50,
                  selected: quantity > 0,
                  isThreeLine: true,
                  dense: false,
                  minLeadingWidth: 0,
                  minVerticalPadding: 12,
                  tileColor: quantity > 0 ? Colors.teal.shade50 : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // builds the save and lookup buttons
  Widget _buildActionButtons(double total) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _savePlan,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save plan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadPlanForDate,
            icon: const Icon(Icons.search),
            label: const Text('Show plan for date'),
          ),
        ),
      ],
    );
  }

  // builds the section showing queried plans
  Widget _buildPlanLookup() {
    if (_queriedPlan == null) {
      return const Text(
        'No plan loaded. Pick a date and tap "Show plan for date".',
      );
    }

    final dateLabel = DateFormat.yMMMd().format(_queriedPlan!.date);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved plan for $dateLabel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.flag, size: 16),
                  label:
                      Text('Target: \$${_queriedPlan!.target.toStringAsFixed(2)}'),
                ),
                Chip(
                  avatar: const Icon(Icons.attach_money, size: 16),
                  label:
                      Text('Total: \$${_queriedPlan!.total.toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._queriedPlan!.items.map(
              (item) => ListTile(
                title: Text(item.food.name),
                subtitle: Text('\$${item.food.price.toStringAsFixed(2)} each'),
                trailing: Text('x${item.quantity}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  const _QuantityChip({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Reduce quantity',
          onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('x$quantity'),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
