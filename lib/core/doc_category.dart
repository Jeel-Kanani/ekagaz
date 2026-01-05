import 'package:flutter/material.dart';

/// High-level zone for documents – matches the 3-tier taxonomy.
///
/// - household: Zone A – Household hub on the home dashboard
/// - memberProfile: Zone B – Inside a specific family member profile
/// - personalPrivate: Zone C – Personal/private space (behind lock)
enum DocCategoryType {
  household,
  memberProfile,
  personalPrivate,
}

/// Strongly-typed document category used across the app.
class DocCategory {
  final String id; // Stable key stored in `documents.category_id`
  final String displayName;
  final IconData icon;
  final DocCategoryType type;

  const DocCategory({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.type,
  });
}

/// Master list of all supported categories.
const List<DocCategory> kDocCategories = [
  // --- HOUSEHOLD (Zone A) ---
  DocCategory(
    id: 'property',
    displayName: 'Property & Living',
    icon: Icons.home,
    type: DocCategoryType.household,
  ),
  DocCategory(
    id: 'vehicle',
    displayName: 'Vehicles',
    icon: Icons.directions_car,
    type: DocCategoryType.household,
  ),
  DocCategory(
    id: 'warranty',
    displayName: 'Assets & Warranty',
    icon: Icons.receipt_long,
    type: DocCategoryType.household,
  ),
  DocCategory(
    id: 'family_insurance',
    displayName: 'Family Health',
    icon: Icons.health_and_safety,
    type: DocCategoryType.household,
  ),

  // --- MEMBER SPECIFIC (Zone B) ---
  DocCategory(
    id: 'identity',
    displayName: 'Identity Proofs',
    icon: Icons.badge,
    type: DocCategoryType.memberProfile,
  ),
  DocCategory(
    id: 'civil',
    displayName: 'Civil Documents',
    icon: Icons.article,
    type: DocCategoryType.memberProfile,
  ),
  DocCategory(
    id: 'banking',
    displayName: 'Banking & Finance',
    icon: Icons.account_balance,
    type: DocCategoryType.memberProfile,
  ),
  DocCategory(
    id: 'education',
    displayName: 'Education',
    icon: Icons.school,
    type: DocCategoryType.memberProfile,
  ),
  DocCategory(
    id: 'medical_history',
    displayName: 'Medical History',
    icon: Icons.medical_services,
    type: DocCategoryType.memberProfile,
  ),

  // --- PERSONAL (Zone C) ---
  DocCategory(
    id: 'study_work',
    displayName: 'Work & Study',
    icon: Icons.menu_book,
    type: DocCategoryType.personalPrivate,
  ),
  DocCategory(
    id: 'secret_vault',
    displayName: 'Secret Vault',
    icon: Icons.lock,
    type: DocCategoryType.personalPrivate,
  ),
];

Iterable<DocCategory> householdCategories() =>
    kDocCategories.where((c) => c.type == DocCategoryType.household);

Iterable<DocCategory> memberProfileCategories() =>
    kDocCategories.where((c) => c.type == DocCategoryType.memberProfile);

Iterable<DocCategory> personalCategories() =>
    kDocCategories.where((c) => c.type == DocCategoryType.personalPrivate);


