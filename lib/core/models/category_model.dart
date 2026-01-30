import 'package:flutter/material.dart';

/// Service Category Model
class CategoryModel {
  final String id;
  final String name;
  final String icon; // Emoji or icon name
  final Color color;
  final int supplierCount;
  final bool isActive;
  final List<String> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.supplierCount = 0,
    this.isActive = true,
    this.subcategories = const [],
  });

  /// Create from Firestore document
  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '📋',
      color: Color(data['color'] ?? 0xFFE3F2FD),
      supplierCount: data['supplierCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      subcategories: List<String>.from(data['subcategories'] ?? []),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'color': color.toARGB32(),
      'supplierCount': supplierCount,
      'isActive': isActive,
      'subcategories': subcategories,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    Color? color,
    int? supplierCount,
    bool? isActive,
    List<String>? subcategories,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      supplierCount: supplierCount ?? this.supplierCount,
      isActive: isActive ?? this.isActive,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}

/// Default categories for initial setup
List<CategoryModel> getDefaultCategories() {
  return [
    CategoryModel(
      id: 'photography',
      name: 'Fotografia',
      icon: '📸',
      color: const Color(0xFFF3E5F5),
      subcategories: ['Fotógrafos', 'Videógrafos', 'Fotografia & Vídeo', 'Drone'],
    ),
    CategoryModel(
      id: 'catering',
      name: 'Catering',
      icon: '🍽️',
      color: const Color(0xFFFFF3E0),
      subcategories: ['Catering completo', 'Bolos', 'Doces', 'Buffet', 'Bar'],
    ),
    CategoryModel(
      id: 'music_dj',
      name: 'Música & DJ',
      icon: '🎵',
      color: const Color(0xFFFCE4EC),
      subcategories: ['DJ', 'Banda ao vivo', 'Som & Iluminação', 'Karaoke'],
    ),
    CategoryModel(
      id: 'decoration',
      name: 'Decoração',
      icon: '🎨',
      color: const Color(0xFFE8F5E9),
      subcategories: ['Decoração de eventos', 'Flores', 'Balões', 'Cenografia'],
    ),
    CategoryModel(
      id: 'venue',
      name: 'Local',
      icon: '🏛️',
      color: const Color(0xFFE3F2FD),
      subcategories: ['Salões de festa', 'Quintas', 'Hotéis', 'Espaços ao ar livre'],
    ),
    CategoryModel(
      id: 'entertainment',
      name: 'Entretenimento',
      icon: '🎭',
      color: const Color(0xFFFFF9C4),
      subcategories: ['Animadores', 'Mágicos', 'Palhaços', 'Artistas'],
    ),
    CategoryModel(
      id: 'transportation',
      name: 'Transporte',
      icon: '🚗',
      color: const Color(0xFFE0F7FA),
      subcategories: ['Carros clássicos', 'Limusines', 'Autocarros', 'Transfer'],
    ),
    CategoryModel(
      id: 'beauty',
      name: 'Beleza',
      icon: '💄',
      color: const Color(0xFFFCE4EC),
      subcategories: ['Maquilhagem', 'Penteados', 'Spa', 'Manicure'],
    ),
  ];
}
