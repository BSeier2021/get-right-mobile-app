import 'package:get_right/utils/trainer_certification_helper.dart';

/// Trainer program/course model
class ProgramModel {
  final String id;
  final String trainerId;
  final String trainerName;
  final String? trainerImage;
  final bool isTrainerCertified;
  final String title;
  final String description;
  final String? thumbnail;
  final double price;
  final String category;
  final int durationWeeks;
  final List<String>? tags;
  final List<ProgramContent>? content;
  final double? rating;
  final int? reviewCount;
  final int enrollmentCount;
  final DateTime createdAt;

  ProgramModel({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    this.trainerImage,
    this.isTrainerCertified = false,
    required this.title,
    required this.description,
    this.thumbnail,
    required this.price,
    required this.category,
    required this.durationWeeks,
    this.tags,
    this.content,
    this.rating,
    this.reviewCount,
    this.enrollmentCount = 0,
    required this.createdAt,
  });

  /// From JSON
  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] ?? '',
      trainerId: json['trainerId'] ?? '',
      trainerName: json['trainerName'] ?? '',
      trainerImage: json['trainerImage'],
      isTrainerCertified: isCertifiedFromUiMap(json),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'],
      price: json['price']?.toDouble() ?? 0.0,
      category: json['category'] ?? '',
      durationWeeks: json['durationWeeks'] ?? 0,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      content: json['content'] != null ? (json['content'] as List).map((item) => ProgramContent.fromJson(item)).toList() : null,
      rating: json['rating']?.toDouble(),
      reviewCount: json['reviewCount'],
      enrollmentCount: json['enrollmentCount'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'trainerImage': trainerImage,
      'isTrainerCertified': isTrainerCertified,
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'price': price,
      'category': category,
      'durationWeeks': durationWeeks,
      'tags': tags,
      'content': content?.map((item) => item.toJson()).toList(),
      'rating': rating,
      'reviewCount': reviewCount,
      'enrollmentCount': enrollmentCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Program content item (video, text, PDF)
class ProgramContent {
  final String id;
  final String title;
  final String type; // 'video', 'text', 'pdf'
  final String? url;
  final String? textContent;
  final int orderIndex;
  final Duration? duration; // For videos

  ProgramContent({required this.id, required this.title, required this.type, this.url, this.textContent, required this.orderIndex, this.duration});

  factory ProgramContent.fromJson(Map<String, dynamic> json) {
    return ProgramContent(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'text',
      url: json['url'],
      textContent: json['textContent'],
      orderIndex: json['orderIndex'] ?? 0,
      duration: json['durationSeconds'] != null ? Duration(seconds: json['durationSeconds']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'type': type, 'url': url, 'textContent': textContent, 'orderIndex': orderIndex, 'durationSeconds': duration?.inSeconds};
  }
}
