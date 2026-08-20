import 'package:flutter_test/flutter_test.dart';
import 'package:meat_partners/core/router/workspace_kind.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  group('workspaceKindForRole', () {
    test('uses the legacy supplier role for the internal catalog workspace',
        () {
      expect(
        workspaceKindForRole(UserRole.supplier),
        PartnerWorkspaceKind.internalCatalog,
      );
    });

    test('keeps qassob and courier workspaces separate', () {
      expect(
          workspaceKindForRole(UserRole.qassob), PartnerWorkspaceKind.qassob);
      expect(
          workspaceKindForRole(UserRole.courier), PartnerWorkspaceKind.courier);
    });

    test('rejects buyer and admin accounts from the work app', () {
      expect(workspaceKindForRole(UserRole.buyer),
          PartnerWorkspaceKind.unsupported);
      expect(workspaceKindForRole(UserRole.admin),
          PartnerWorkspaceKind.unsupported);
    });
  });
}
