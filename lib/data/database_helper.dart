import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import '../models/order_plan.dart';
import '../models/plan_item.dart';

/// Handles database interactions for menu items and order plans.
class DatabaseHelper {
  /// Private constructor to support the singleton pattern.
  DatabaseHelper._internal();

  /// Shared instance of the helper.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Underlying database reference.
  Database? _database;

  /// Opens the database, creating tables if needed.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  /// Opens a new database connection and seeds menu entries.
  Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'food_planner.db');

    final db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            price REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE order_plans(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_date TEXT,
            target_cost REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE plan_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER,
            food_id INTEGER,
            quantity INTEGER,
            FOREIGN KEY(plan_id) REFERENCES order_plans(id) ON DELETE CASCADE,
            FOREIGN KEY(food_id) REFERENCES food_items(id)
          )
        ''');
        await _seedMenu(db);
      },
    );

    await _seedMenu(db);
    return db;
  }

  /// Seeds the database with a default menu if empty.
  Future<void> _seedMenu(Database db) async {
    final existing = await db.query('food_items', limit: 1);
    if (existing.isNotEmpty) return;

    final defaults = <FoodItem>[
      const FoodItem(name: 'Margherita Pizza', price: 10.5),
      const FoodItem(name: 'Grilled Chicken Bowl', price: 12.0),
      const FoodItem(name: 'Sushi Platter', price: 18.5),
      const FoodItem(name: 'Avocado Toast', price: 8.5),
      const FoodItem(name: 'Pasta Carbonara', price: 13.0),
      const FoodItem(name: 'Vegan Buddha Bowl', price: 11.0),
      const FoodItem(name: 'Beef Burger', price: 9.5),
      const FoodItem(name: 'Caesar Salad', price: 7.5),
      const FoodItem(name: 'Pad Thai', price: 12.5),
      const FoodItem(name: 'Tacos Trio', price: 9.0),
      const FoodItem(name: 'Seafood Paella', price: 17.0),
      const FoodItem(name: 'Falafel Wrap', price: 8.0),
      const FoodItem(name: 'Chicken Shawarma', price: 9.0),
      const FoodItem(name: 'Ramen Bowl', price: 14.0),
      const FoodItem(name: 'BBQ Brisket Sandwich', price: 11.5),
      const FoodItem(name: 'Greek Gyro', price: 8.5),
      const FoodItem(name: 'Smoothie Bowl', price: 6.5),
      const FoodItem(name: 'Steak Frites', price: 19.0),
      const FoodItem(name: 'Chocolate Lava Cake', price: 6.0),
      const FoodItem(name: 'Iced Latte', price: 4.5),
    ];

    for (final item in defaults) {
      await db.insert('food_items', item.toMap());
    }
  }

  /// Retrieves the full menu from the database.
  Future<List<FoodItem>> fetchMenu() async {
    final db = await database;
    final rows = await db.query('food_items', orderBy: 'name ASC');
    return rows.map((e) => FoodItem.fromMap(e)).toList();
  }

  /// Adds a new food item entry to the database.
  Future<FoodItem> insertFoodItem(FoodItem item) async {
    final db = await database;
    final id = await db.insert('food_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item.copyWith(id: id);
  }

  /// Updates an existing food item entry.
  Future<void> updateFoodItem(FoodItem item) async {
    final db = await database;
    await db.update(
      'food_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Deletes a food item by its identifier.
  Future<void> deleteFoodItem(int id) async {
    final db = await database;
    await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  /// Saves an order plan for a given date, replacing any existing one.
  Future<void> saveOrderPlan(OrderPlan plan) async {
    final db = await database;
    final dateString = _dateKey(plan.date);

    await db.transaction((txn) async {
      final existing = await txn.query(
        'order_plans',
        where: 'plan_date = ?',
        whereArgs: [dateString],
      );

      int planId;
      if (existing.isNotEmpty) {
        planId = existing.first['id'] as int;
        await txn.update(
          'order_plans',
          {'target_cost': plan.targetCost, 'plan_date': dateString},
          where: 'id = ?',
          whereArgs: [planId],
        );
        await txn.delete('plan_items', where: 'plan_id = ?', whereArgs: [planId]);
      } else {
        planId = await txn.insert('order_plans', {
          'plan_date': dateString,
          'target_cost': plan.targetCost,
        });
      }

      for (final item in plan.items) {
        await txn.insert('plan_items', {
          'plan_id': planId,
          'food_id': item.item.id,
          'quantity': item.quantity,
        });
      }
    });
  }

  /// Fetches an order plan for a specific date.
  Future<OrderPlan?> fetchPlanByDate(DateTime date) async {
    final db = await database;
    final dateString = _dateKey(date);

    final plans = await db.query(
      'order_plans',
      where: 'plan_date = ?',
      whereArgs: [dateString],
    );

    if (plans.isEmpty) return null;

    final planId = plans.first['id'] as int;
    final target = (plans.first['target_cost'] as num).toDouble();

    final menu = await fetchMenu();
    final menuById = {for (var item in menu) item.id: item};

    final planItems = await db.query(
      'plan_items',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );

    final selections = planItems
        .map((row) => PlanItem(
              item: menuById[row['food_id'] as int]!,
              quantity: row['quantity'] as int,
            ))
        .toList();

    return OrderPlan(
      id: planId,
      date: DateTime.parse(dateString),
      targetCost: target,
      items: selections,
    );
  }

  /// Deletes a stored order plan by its identifier.
  Future<void> deletePlan(int id) async {
    final db = await database;
    await db.delete('order_plans', where: 'id = ?', whereArgs: [id]);
  }

  /// Formats a DateTime into the storage key.
  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
