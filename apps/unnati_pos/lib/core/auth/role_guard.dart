// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// The Unnati staff roles.
enum StaffRole { owner, manager, cashier }

extension StaffRoleExt on StaffRole {
  bool get canViewCostPrice => this == StaffRole.owner;
  bool get canViewNetProfit => this == StaffRole.owner;
  bool get canDeleteSale => this == StaffRole.owner || this == StaffRole.manager;
  bool get canManageStaff => this == StaffRole.owner;
  bool get canViewReports => this != StaffRole.cashier;
  bool get canManageProducts => this != StaffRole.cashier;
}

/// [RoleGuard] conditionally renders a child widget based on the current
/// user's role. If the user's role doesn't meet the requirement, it renders
/// [placeholder] (default: empty SizedBox).
///
/// Usage:
/// ```dart
/// RoleGuard(
///   requiredRole: StaffRole.owner,
///   child: CostPriceLabel(price: product.costPrice),
/// )
/// ```
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
    this.placeholder,
  });

  final StaffRole requiredRole;
  final Widget child;

  /// Shown when the user does not have permission. Defaults to invisible.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userRole = authState.role;

    final hasPermission = _hasRole(userRole, requiredRole);

    if (hasPermission) return child;
    return placeholder ?? const SizedBox.shrink();
  }

  bool _hasRole(StaffRole userRole, StaffRole required) {
    // Owner can see everything
    if (userRole == StaffRole.owner) return true;
    
    // Manager can see manager-and-below content
    if (userRole == StaffRole.manager && required == StaffRole.manager) return true;
    if (userRole == StaffRole.manager && required == StaffRole.cashier) return true;
    
    // Cashier can only see cashier-level content
    if (userRole == StaffRole.cashier && required == StaffRole.cashier) return true;
    
    return false;
  }
}

/// [PermissionGuard] guards based on specific permissions rather than roles.
class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.placeholder,
  });

  final String permission; // e.g., 'view_cost_price', 'view_net_profit'
  final Widget child;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final role = authState.role;

    final allowed = _checkPermission(role, permission);

    return allowed ? child : (placeholder ?? const SizedBox.shrink());
  }

  bool _checkPermission(StaffRole role, String perm) {
    switch (perm) {
      case 'view_cost_price':
        return role.canViewCostPrice;
      case 'view_net_profit':
        return role.canViewNetProfit;
      case 'delete_sale':
        return role.canDeleteSale;
      case 'manage_staff':
        return role.canManageStaff;
      case 'view_reports':
        return role.canViewReports;
      case 'manage_products':
        return role.canManageProducts;
      default:
        return false;
    }
  }
}
