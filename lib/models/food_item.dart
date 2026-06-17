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

  /// Mongo-style `_id` as string or `{ "\$oid": "..." }` after JSON decode.
  static String? _nutritionApiIdToString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    if (raw is Map) {
      final oid = raw[r'$oid'];
      if (oid != null) {
        final o = oid.toString().trim();
        if (o.isNotEmpty) return o;
      }
    }
    return null;
  }

  /// Nested `meal` from API (has `mealType`, no macros) — must not be merged as the food document.
  static bool _mapLooksLikeMealRef(Map<String, dynamic> m) {
    final hasMealType = m['mealType'] != null;
    final hasMacros = m['proteinG'] != null || m['calories'] != null || m['carbsG'] != null || m['fatG'] != null;
    return hasMealType && !hasMacros;
  }

  /// Some list responses wrap the food row or use a junction `_id`; merge nested `food` for PATCH/DELETE id + fields.
  static Map<String, dynamic> _flattenNutritionCustomFoodJson(Map<String, dynamic> json) {
    final food = json['food'];
    if (food is Map) {
      try {
        final fm = Map<String, dynamic>.from(food);
        if (!_mapLooksLikeMealRef(fm)) {
          return {...json, ...fm};
        }
      } catch (_) {}
    }
    return Map<String, dynamic>.from(json);
  }

  static String _nutritionCustomFoodDocumentId(Map<String, dynamic> merged) {
    for (final key in ['customFoodId', 'foodId', 'nutritionFoodId']) {
      final s = _nutritionApiIdToString(merged[key]);
      if (s != null && s.isNotEmpty) return s;
    }
    return _nutritionApiIdToString(merged['_id']) ?? _nutritionApiIdToString(merged['id']) ?? '';
  }

  /// `GET /customer/food-saves` row (`_id`, `macronutrients`, `servingSize`, `unit`, …).
  factory FoodItem.fromFoodSaveApi(Map<String, dynamic> json) {
    final food = json['food'];
    final merged = food is Map ? {...json, ...Map<String, dynamic>.from(food)} : json;

    final id = _nutritionApiIdToString(merged['_id']) ?? _nutritionApiIdToString(merged['id']) ?? '';
    final servingSize = _toD(merged['servingSize'] == null ? 1.0 : merged['servingSize']);
    final unit = merged['unit']?.toString() ?? 'serving';
    final macros = merged['macronutrients'];
    var protein = 0.0;
    var carbs = 0.0;
    var fats = 0.0;
    if (macros is Map) {
      protein = _toD(macros['protein']);
      carbs = _toD(macros['carbs']);
      fats = _toD(macros['fats']);
    }
    return FoodItem(
      id: id,
      name: merged['name']?.toString() ?? '',
      calories: _toD(merged['calories']),
      protein: protein,
      carbs: carbs,
      fats: fats,
      defaultServingSize: 1.0,
      servingUnit: '$servingSize $unit'.trim(),
      isSaved: true,
      createdAt: merged['createdAt'] != null ? DateTime.tryParse(merged['createdAt'].toString()) : null,
      isNutritionApiCustom: true,
      nutritionApiServingSize: servingSize,
      nutritionApiServingUnit: unit,
    );
  }

  /// Merge PUT response with submitted values when API omits fields like `name`.
  FoodItem mergeFoodSaveUpdate({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    FoodItem? fromApi,
  }) {
    final hasFullApiRow = fromApi != null && fromApi.name.isNotEmpty;
    final api = fromApi;
    return copyWith(
      id: (api?.id.isNotEmpty == true) ? api!.id : id,
      name: hasFullApiRow ? api!.name : name.trim(),
      calories: hasFullApiRow ? api!.calories : calories,
      protein: hasFullApiRow ? api!.protein : protein,
      carbs: hasFullApiRow ? api!.carbs : carbs,
      fats: hasFullApiRow ? api!.fats : fats,
      nutritionApiServingSize: fromApi?.nutritionApiServingSize ?? nutritionApiServingSize,
      nutritionApiServingUnit: fromApi?.nutritionApiServingUnit ?? nutritionApiServingUnit,
      servingUnit: (fromApi?.servingUnit?.isNotEmpty == true) ? fromApi!.servingUnit : servingUnit,
      isNutritionApiCustom: true,
      isSaved: true,
    );
  }

  /// Nutrition API food row (`_id`, `proteinG`, `servingLabel`, …).
  factory FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic> json) {
    final merged = _flattenNutritionCustomFoodJson(json);
    final id = _nutritionCustomFoodDocumentId(merged);
    final servingSize = _toD(merged['servingSize'] == null ? 1.0 : merged['servingSize']);
    final unit = merged['servingUnit']?.toString() ?? 'serving';
    final label = merged['servingLabel']?.toString();
    return FoodItem(
      id: id,
      name: merged['name']?.toString() ?? '',
      calories: _toD(merged['calories']),
      protein: _toD(merged['proteinG'] ?? merged['protein']),
      carbs: _toD(merged['carbsG'] ?? merged['carbs']),
      fats: _toD(merged['fatG'] ?? merged['fats']),
      defaultServingSize: 1.0,
      servingUnit: (label != null && label.isNotEmpty) ? label : '$servingSize $unit'.trim(),
      isSaved: true,
      createdAt: merged['createdAt'] != null ? DateTime.tryParse(merged['createdAt'].toString()) : null,
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

