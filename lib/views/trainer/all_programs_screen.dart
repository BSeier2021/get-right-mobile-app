import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// All Programs screen - displays all programs from a trainer section
class AllProgramsScreen extends StatelessWidget {
  const AllProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dynamic arguments = Get.arguments;
    List<Map<String, dynamic>> programs = [];
    String sectionTitle = 'All Programs';
    Map<String, dynamic>? trainer;

    try {
      if (arguments != null) {
        Map<String, dynamic>? argsMap;

        if (arguments is Map<String, dynamic>) {
          argsMap = arguments;
        } else if (arguments is Map) {
          argsMap = Map<String, dynamic>.from(arguments);
        }

        if (argsMap != null) {
          // Handle programs list
          final programsData = argsMap['programs'];
          if (programsData != null && programsData is List) {
            programs = programsData.map<Map<String, dynamic>>((item) {
              if (item is Map<String, dynamic>) {
                return item;
              } else if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return <String, dynamic>{};
            }).toList();
          }

          sectionTitle = argsMap['section']?.toString() ?? 'All Programs';
          final trainerData = argsMap['trainer'];
          if (trainerData != null && trainerData is Map) {
            trainer = Map<String, dynamic>.from(trainerData);
          }
        }
      }
    } catch (e) {
      // If there's an error, programs will remain empty
      print('Error parsing arguments: $e');
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(sectionTitle, style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trainer != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accent,
                    child: Text(trainer['initials'] ?? 'T', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onAccent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainer['name'] ?? 'Trainer',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                        ),
                        Text('${programs.length} Programs', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else
              Text('${programs.length} Programs Available', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
            const SizedBox(height: 16),
            if (programs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primaryGray.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No programs found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                      const SizedBox(height: 8),
                      Text('Received ${programs.length} programs', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  return _buildProgramCard(programs[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.programDetail, arguments: program),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.network(
                    program['imageUrl'] ?? 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                    ),
                  ),
                ),
                // Certified badge
                if (program['certified'] ?? false)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.completed, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),

            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      program['title'] ?? 'Program',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Instructor
                    Text(
                      program['trainer'] ?? 'Trainer',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Rating
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (program['rating'] ?? 0.0).toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                        const SizedBox(width: 3),
                        ...List.generate(
                          5,
                          (index) => Icon(index < ((program['rating'] ?? 0.0) as double).floor() ? Icons.star : Icons.star_border, color: const Color(0xFFE59819), size: 11),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '(${_formatNumber(program['students'] ?? 0)})',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Price and Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 10, color: AppColors.primaryGray),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  program['duration'] ?? 'N/A',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(program['price'] ?? 0.0).toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
