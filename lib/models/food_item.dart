/// Model for a food item (saved or custom)
class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double defaultServingSize;
  final String? servingUnit;
  final String? imageUrl;
  final bool isSaved;
  final DateTime? createdAt;

  /// From `GET /nutrition/foods/custom`.
  final bool isNutritionApiCustom;

  /// Raw `servingSize` / `servingUnit` from nutrition API (for PATCH body). Display may use [servingLabel] only.
  final double? nutritionApiServingSize;
  final String? nutritionApiServingUnit;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.defaultServingSize = 1.0,
    this.servingUnit = 'serving',
    this.imageUrl,
    this.isSaved = false,
    DateTime? createdAt,
    this.isNutritionApiCustom = false,
    this.nutritionApiServingSize,
    this.nutritionApiServingUnit,
  }) : createdAt = createdAt ?? DateTime.now();

  // Calculate nutrition based on quantity
  Map<String, double> calculateForQuantity(double quantity) {
    return {'calories': calories * quantity, 'protein': protein * quantity, 'carbs': carbs * quantity, 'fats': fats * quantity};
  }

  // From JSON
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fats: (json['fats'] ?? 0).toDouble(),
      defaultServingSize: (json['defaultServingSize'] ?? 1.0).toDouble(),
      servingUnit: json['servingUnit'],
      imageUrl: json['imageUrl'],
      isSaved: json['isSaved'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      isNutritionApiCustom: json['isNutritionApiCustom'] == true,
      nutritionApiServingSize: json['nutritionApiServingSize'] != null ? (json['nutritionApiServingSize'] as num).toDouble() : null,
      nutritionApiServingUnit: json['nutritionApiServingUnit']?.toString(),
    );
  }

  static double _toD(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Nutrition API food row (`_id`, `proteinG`, `servingLabel`, …).
  factory FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final servingSize = _toD(json['servingSize'] == null ? 1.0 : json['servingSize']);
    final unit = json['servingUnit']?.toString() ?? 'serving';
    final label = json['servingLabel']?.toString();
    return FoodItem(
      id: id,
      name: json['name']?.toString() ?? '',
      calories: _toD(json['calories']),
      protein: _toD(json['proteinG'] ?? json['protein']),
      carbs: _toD(json['carbsG'] ?? json['carbs']),
      fats: _toD(json['fatG'] ?? json['fats']),
      defaultServingSize: 1.0,
      servingUnit: (label != null && label.isNotEmpty) ? label : '$servingSize $unit'.trim(),
      isSaved: true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      isNutritionApiCustom: true,
      nutritionApiServingSize: servingSize,
      nutritionApiServingUnit: unit,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'defaultServingSize': defaultServingSize,
      'servingUnit': servingUnit,
      'imageUrl': imageUrl,
      'isSaved': isSaved,
      'createdAt': createdAt?.toIso8601String(),
      'isNutritionApiCustom': isNutritionApiCustom,
      'nutritionApiServingSize': nutritionApiServingSize,
      'nutritionApiServingUnit': nutritionApiServingUnit,
    };
  }

  // Copy with
  FoodItem copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? defaultServingSize,
    String? servingUnit,
    String? imageUrl,
    bool? isSaved,
    DateTime? createdAt,
    bool? isNutritionApiCustom,
    double? nutritionApiServingSize,
    String? nutritionApiServingUnit,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      defaultServingSize: defaultServingSize ?? this.defaultServingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      imageUrl: imageUrl ?? this.imageUrl,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt ?? this.createdAt,
      isNutritionApiCustom: isNutritionApiCustom ?? this.isNutritionApiCustom,
      nutritionApiServingSize: nutritionApiServingSize ?? this.nutritionApiServingSize,
      nutritionApiServingUnit: nutritionApiServingUnit ?? this.nutritionApiServingUnit,
    );
  }
}

