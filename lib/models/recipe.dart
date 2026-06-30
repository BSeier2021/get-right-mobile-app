import 'package:get_right/utils/image_url_sanitizer.dart';

/// Model for a recipe ingredient
class RecipeIngredient {
  final String name;
  final String quantity;
  final String? unit;

  RecipeIngredient({required this.name, required this.quantity, this.unit});

  String get displayText => unit != null ? '$quantity $unit $name' : '$quantity $name';

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(name: json['name'] ?? '', quantity: json['quantity'] ?? '', unit: json['unit']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'unit': unit};
  }
}

/// Model for recipe cooking instructions
class RecipeInstruction {
  final int step;
  final String instruction;

  RecipeInstruction({required this.step, required this.instruction});

  factory RecipeInstruction.fromJson(Map<String, dynamic> json) {
    return RecipeInstruction(step: json['step'] ?? 0, instruction: json['instruction'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'step': step, 'instruction': instruction};
  }
}

/// Recipe category tags
enum RecipeCategory {
  breakfast,
  lunch,
  dinner,
  snacks,
  bodybuilding,
  lowCarb,
  highProtein,
  vegetarian,
  vegan,
  budgetFriendly,
  quickPrep;

  String get displayName {
    switch (this) {
      case RecipeCategory.breakfast:
        return 'Breakfast';
      case RecipeCategory.lunch:
        return 'Lunch';
      case RecipeCategory.dinner:
        return 'Dinner';
      case RecipeCategory.snacks:
        return 'Snacks';
      case RecipeCategory.bodybuilding:
        return 'Bodybuilding';
      case RecipeCategory.lowCarb:
        return 'Low Carb';
      case RecipeCategory.highProtein:
        return 'High Protein';
      case RecipeCategory.vegetarian:
        return 'Vegetarian';
      case RecipeCategory.vegan:
        return 'Vegan';
      case RecipeCategory.budgetFriendly:
        return 'Budget-Friendly';
      case RecipeCategory.quickPrep:
        return 'Quick Prep';
    }
  }
}

/// Model for a cookbook recipe
class Recipe {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<RecipeCategory> categories;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<RecipeInstruction> instructions;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatsPerServing;
  final double? estimatedCost;
  final double? costPerServing;
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final bool isPremium;
  final bool isFeatured;
  final DateTime? createdAt;
  final int? popularity;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.categories,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatsPerServing,
    this.estimatedCost,
    this.costPerServing,
    this.videoUrl,
    this.videoThumbnailUrl,
    this.isPremium = false,
    this.isFeatured = false,
    this.createdAt,
    this.popularity,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  bool get hasWalkthroughVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  String get walkthroughPosterUrl {
    final thumb = videoThumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return imageUrl;
  }

  // Calculate nutrition for multiple servings
  Map<String, double> calculateForServings(double servingCount) {
    return {
      'calories': caloriesPerServing * servingCount,
      'protein': proteinPerServing * servingCount,
      'carbs': carbsPerServing * servingCount,
      'fats': fatsPerServing * servingCount,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe.fromApiJson(json);
  }

  factory Recipe.fromApiJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final mealType = json['mealType']?.toString().trim();
    final categories = <RecipeCategory>[];
    final fromMeal = _categoryFromMealType(mealType);
    if (fromMeal != null) categories.add(fromMeal);

    final tags = json['tags'] ?? json['categories'];
    if (tags is List) {
      for (final tag in tags) {
        String? tagName;
        if (tag is Map) {
          tagName = Map<String, dynamic>.from(tag)['name']?.toString();
        } else {
          tagName = tag?.toString();
        }
        final cat = _categoryFromTag(tagName);
        if (cat != null && !categories.contains(cat)) categories.add(cat);
      }
    }

    final categoryLabel = json['category']?.toString().trim();
    if (categoryLabel != null && categoryLabel.isNotEmpty) {
      final fromCategory = _categoryFromTag(categoryLabel);
      if (fromCategory != null && !categories.contains(fromCategory)) categories.add(fromCategory);
    }

    final prep = ((json['prepTimeMinutes'] ?? json['prepTime'] ?? json['prepMinutes']) as num?)?.toInt() ?? 0;
    final cook = ((json['cookTimeMinutes'] ?? json['cookTime'] ?? json['cookMinutes']) as num?)?.toInt() ?? 0;
    final totalTime = (json['totalTimeMinutes'] ?? json['totalTime'] as num?)?.toInt();
    final prepTime = prep > 0 ? prep : (totalTime != null && totalTime > cook ? totalTime - cook : totalTime ?? 0);
    final cookTime = cook > 0 ? cook : 0;

    final macros = json['macronutrients'] ?? json['nutrition'];
    double macro(String key, List<String> alt) {
      if (macros is Map) {
        final m = Map<String, dynamic>.from(macros);
        for (final k in alt) {
          final v = m[k];
          if (v is num) return v.toDouble();
        }
      }
      for (final k in alt) {
        final v = json[k];
        if (v is num) return v.toDouble();
      }
      return 0;
    }

    return Recipe(
      id: id,
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Recipe',
      description: json['description']?.toString() ?? '',
      imageUrl: _imageUrlFromApi(json),
      categories: categories.isEmpty ? [RecipeCategory.dinner] : categories,
      prepTimeMinutes: prepTime,
      cookTimeMinutes: cookTime,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      ingredients: _ingredientsFromApi(json['ingredients']),
      instructions: _instructionsFromApi(json['instructions'] ?? json['steps']),
      caloriesPerServing: macro('calories', ['calories', 'caloriesPerServing', 'calorie']),
      proteinPerServing: macro('protein', ['protein', 'proteinPerServing', 'proteinG', 'proteinGrams']),
      carbsPerServing: macro('carbs', ['carbs', 'carbsPerServing', 'carbsG', 'carbsGrams']),
      fatsPerServing: macro('fats', ['fats', 'fatsPerServing', 'fatG', 'fat', 'fatGrams']),
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? (json['netPrice'] as num?)?.toDouble(),
      costPerServing: (json['costPerServing'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble(),
      videoUrl: _videoUrlFromApi(json),
      videoThumbnailUrl: _videoThumbnailFromApi(json),
      isPremium: json['isPremium'] == true || json['premium'] == true || (json.containsKey('isFree') && json['isFree'] != true),
      isFeatured: json['isFeatured'] == true || json['featured'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      popularity: (json['popularity'] as num?)?.toInt(),
    );
  }

  static RecipeCategory? _categoryFromMealType(String? mealType) {
    switch (mealType?.trim()) {
      case 'Breakfast':
        return RecipeCategory.breakfast;
      case 'Lunch':
        return RecipeCategory.lunch;
      case 'Dinner':
        return RecipeCategory.dinner;
      case 'Snacks':
        return RecipeCategory.snacks;
      default:
        return null;
    }
  }

  static RecipeCategory? _categoryFromTag(String? raw) {
    final s = raw?.trim().toLowerCase().replaceAll(' ', '');
    if (s == null || s.isEmpty) return null;
    for (final cat in RecipeCategory.values) {
      if (cat.name.toLowerCase() == s || cat.displayName.toLowerCase().replaceAll('-', '').replaceAll(' ', '') == s) {
        return cat;
      }
    }
    if (s.contains('protein')) return RecipeCategory.highProtein;
    if (s.contains('lowcarb')) return RecipeCategory.lowCarb;
    return null;
  }

  static String _imageUrlFromApi(Map<String, dynamic> json) {
    String? pick(dynamic v) => ImageUrlSanitizer.asHttpUrlOrNull(v?.toString());

    final image = json['image'];
    if (image is Map) {
      final url = pick(Map<String, dynamic>.from(image)['url']);
      if (url != null) return url;
    }

    final direct = pick(json['imageUrl'] ?? json['thumbnail']);
    if (direct != null) return direct;

    final media = json['imageMedia'] ?? json['coverImage'] ?? json['promoMedia'] ?? json['photo'];
    if (media is Map) {
      final url = pick(Map<String, dynamic>.from(media)['url']);
      if (url != null) return url;
    }
    return '';
  }

  static String? _videoUrlFromApi(Map<String, dynamic> json) {
    final walkthrough = json['walkthroughVideo'];
    if (walkthrough is Map) {
      final url = ImageUrlSanitizer.asHttpUrlOrNull(Map<String, dynamic>.from(walkthrough)['url']?.toString());
      if (url != null) return url;
    }
    final legacy = json['videoUrl']?.toString() ?? json['video']?.toString();
    return legacy != null && legacy.isNotEmpty ? legacy : null;
  }

  static String? _videoThumbnailFromApi(Map<String, dynamic> json) {
    final walkthrough = json['walkthroughVideo'];
    if (walkthrough is! Map) return null;
    final wm = Map<String, dynamic>.from(walkthrough);
    final thumbnail = wm['thumbnail'];
    if (thumbnail is Map) {
      return ImageUrlSanitizer.asHttpUrlOrNull(Map<String, dynamic>.from(thumbnail)['url']?.toString());
    }
    return ImageUrlSanitizer.asHttpUrlOrNull(wm['thumbnailUrl']?.toString());
  }

  static List<RecipeIngredient> _ingredientsFromApi(dynamic raw) {
    if (raw is! List) return const [];
    final out = <RecipeIngredient>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is String) {
        out.add(RecipeIngredient(name: item, quantity: ''));
        continue;
      }
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      out.add(
        RecipeIngredient(
          name: m['name']?.toString() ?? m['ingredient']?.toString() ?? '',
          quantity: m['quantity']?.toString() ?? m['amount']?.toString() ?? '',
          unit: m['unit']?.toString(),
        ),
      );
    }
    return out;
  }

  static List<RecipeInstruction> _instructionsFromApi(dynamic raw) {
    if (raw is! List) return const [];
    final out = <RecipeInstruction>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is String) {
        out.add(RecipeInstruction(step: i + 1, instruction: item));
        continue;
      }
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      out.add(
        RecipeInstruction(
          step: (m['step'] as num?)?.toInt() ?? (m['order'] as num?)?.toInt() ?? (i + 1),
          instruction: m['instruction']?.toString() ?? m['text']?.toString() ?? m['description']?.toString() ?? '',
        ),
      );
    }
    return out;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'categories': categories.map((c) => c.name).toList(),
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'servings': servings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions.map((i) => i.toJson()).toList(),
      'caloriesPerServing': caloriesPerServing,
      'proteinPerServing': proteinPerServing,
      'carbsPerServing': carbsPerServing,
      'fatsPerServing': fatsPerServing,
      'estimatedCost': estimatedCost,
      'costPerServing': costPerServing,
      'videoUrl': videoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'isPremium': isPremium,
      'isFeatured': isFeatured,
      'createdAt': createdAt?.toIso8601String(),
      'popularity': popularity,
    };
  }
}

