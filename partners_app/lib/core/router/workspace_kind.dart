import 'package:shared_core/shared_core.dart';

/// User-facing workspace selected from the backend role.
///
/// `UserRole.supplier` remains a wire-level compatibility detail. In this app it represents the
/// platform's own catalog team, not an external supplier account.
enum PartnerWorkspaceKind {
  internalCatalog,
  qassob,
  courier,
  unsupported,
}

PartnerWorkspaceKind workspaceKindForRole(UserRole role) => switch (role) {
      UserRole.supplier => PartnerWorkspaceKind.internalCatalog,
      UserRole.qassob => PartnerWorkspaceKind.qassob,
      UserRole.courier => PartnerWorkspaceKind.courier,
      UserRole.admin || UserRole.buyer => PartnerWorkspaceKind.unsupported,
    };
