import 'package:flutter/material.dart';

/// Represents a menu item stored in the local database.
@immutable
class FoodItem {
  /// Unique identifier from the database.
  final int? id;

  /// The readable name of the dish.
  final String name;

  /// The unit price for the dish.
  final double price;

  /// Builds an immutable food item.
  const FoodItem({this.id, required this.name, required this.price});

  /// Copies a food item with new values.
  FoodItem copyWith({int? id, String? name, double? price}) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }

  /// Converts the object to a map for SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  /// Restores a food item from a map.
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }
}
