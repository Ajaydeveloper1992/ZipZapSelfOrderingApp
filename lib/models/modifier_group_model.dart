import 'dart:convert';
import 'package:flutter/foundation.dart';

class ModifierGroup {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool enabled;
  final int requiredModifiersCount;
  final int allowedModifiersCount;
  final List<Modifier> modifiers;
  final List<String> products;
  final int sortOrder;

  ModifierGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.enabled,
    required this.requiredModifiersCount,
    required this.allowedModifiersCount,
    required this.modifiers,
    required this.products,
    required this.sortOrder,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    try {
      // API returns pos/web nested objects, prefer pos for POS app
      final posData = json['pos'] as Map<String, dynamic>?;

      // First try to get modifiers from nested structure
      final nestedModifiers = (json['modifiers'] as List<dynamic>? ?? [])
          .map((m) {
            try {
              return Modifier.fromJson(m as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Error parsing modifier in group: $e');
              return null;
            }
          })
          .whereType<Modifier>()
          .where((m) => m.isActive)
          .toList();

      return ModifierGroup(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        name: posData?['name']?.toString() ?? json['name']?.toString() ?? '',
        description:
            posData?['description']?.toString() ??
            json['description']?.toString() ??
            '',
        isActive:
            posData?['isActive'] as bool? ?? json['isActive'] as bool? ?? true,
        enabled:
            posData?['enabled'] as bool? ?? json['enabled'] as bool? ?? true,
        requiredModifiersCount:
            (posData?['requiredModifiersCount'] as num?)?.toInt() ??
            (json['requiredModifiersCount'] as num?)?.toInt() ??
            0,
        allowedModifiersCount:
            (posData?['allowedModifiersCount'] as num?)?.toInt() ??
            (json['allowedModifiersCount'] as num?)?.toInt() ??
            0,
        modifiers: nestedModifiers,
        products:
            (json['selectedProducts'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            (json['products'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing ModifierGroup from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      try {
        final jsonStr = jsonEncode(json);
        debugPrint('JSON data: $jsonStr');
      } catch (_) {
        debugPrint('JSON data (ID only): ${json['_id'] ?? json['id']}');
      }
      // Return a minimal valid ModifierGroup to prevent app crash
      final posData = json['pos'] as Map<String, dynamic>?;
      return ModifierGroup(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        name:
            posData?['name']?.toString() ??
            json['name']?.toString() ??
            'Unknown',
        description:
            posData?['description']?.toString() ??
            json['description']?.toString() ??
            '',
        isActive:
            posData?['isActive'] as bool? ?? json['isActive'] as bool? ?? false,
        enabled:
            posData?['enabled'] as bool? ?? json['enabled'] as bool? ?? false,
        requiredModifiersCount: 0,
        allowedModifiersCount: 0,
        modifiers: [],
        products: [],
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
    }
  }

  ModifierGroup copyWithModifiers(List<Modifier> modifiers) {
    return ModifierGroup(
      id: id,
      name: name,
      description: description,
      isActive: isActive,
      enabled: enabled,
      requiredModifiersCount: requiredModifiersCount,
      allowedModifiersCount: allowedModifiersCount,
      modifiers: modifiers,
      products: products,
      sortOrder: sortOrder,
    );
  }
}

class Modifier {
  final String id;
  final String name;
  final double priceAdjustment;
  final bool isActive;
  final String? modifierGroupId;
  final bool posEnabled;

  Modifier({
    required this.id,
    required this.name,
    required this.priceAdjustment,
    required this.isActive,
    this.modifierGroupId,
    this.posEnabled = true,
  });

  factory Modifier.fromJson(Map<String, dynamic> json) {
    try {
      return Modifier(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        priceAdjustment: (json['priceAdjustment'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] as bool? ?? true,
        modifierGroupId:
            json['modifierGroup']?.toString() ??
            json['modifiersgroup']?.toString(),
        posEnabled: json['posEnabled'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing Modifier from JSON: $e');
      // Return a minimal valid Modifier to prevent app crash
      return Modifier(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        priceAdjustment: 0.0,
        isActive: false,
        modifierGroupId:
            json['modifierGroup']?.toString() ??
            json['modifiersgroup']?.toString(),
        posEnabled: false,
      );
    }
  }
}
