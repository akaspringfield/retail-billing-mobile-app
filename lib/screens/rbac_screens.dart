import 'package:flutter/material.dart';

import '../data_utils.dart';
import '../people_service.dart';
import '../rbac_service.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

enum RbacKind { roles, permissions, rolePermissions, userRoles }

class RbacScreen extends StatefulWidget {
  const RbacScreen({
    super.key,
    required this.service,
    required this.people,
    required this.kind,
  });

  final RbacService service;
  final PeopleService people;
  final RbacKind kind;

  @override
  State<RbacScreen> createState() => _RbacScreenState();
}

class _RbacScreenState extends State<RbacScreen> {
  late Future<void> future = load();
  List<Map<String, dynamic>> roles = [];
  List<Map<String, dynamic>> permissions = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> rolePermissions = [];
  List<Map<String, dynamic>> userRoles = [];
  List<Map<String, dynamic>> users = [];
  String? selectedRoleUuid;
  String message = '';

  String get title => switch (widget.kind) {
        RbacKind.roles => 'Roles',
        RbacKind.permissions => 'Permissions',
        RbacKind.rolePermissions => 'Role Permissions',
        RbacKind.userRoles => 'User Roles',
      };

  String get route => switch (widget.kind) {
        RbacKind.roles => '/roles',
        RbacKind.permissions => '/permissions',
        RbacKind.rolePermissions => '/role-permissions',
        RbacKind.userRoles => '/user-roles',
      };

  Future<void> load() async {
    message = '';
    if (widget.kind == RbacKind.roles) {
      roles = await widget.service.roles();
    } else if (widget.kind == RbacKind.permissions) {
      groups = await widget.service.permissionGroups();
      permissions = await widget.service.permissions();
    } else if (widget.kind == RbacKind.rolePermissions) {
      roles = await widget.service.roles();
      permissions = await widget.service.permissions();
      selectedRoleUuid ??= roles.isNotEmpty ? textValue(roles.first, ['uuid'], fallback: '') : null;
      rolePermissions = selectedRoleUuid?.isNotEmpty == true
          ? await widget.service.rolePermissions(selectedRoleUuid!)
          : [];
    } else {
      userRoles = await widget.service.userRoles();
      roles = await widget.service.roles();
      users = await widget.people.users();
    }
  }

  void reload() => setState(() => future = load());

  Future<void> createRole() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoleSheet(service: widget.service),
    );
    if (saved == true) reload();
  }

  Future<void> assignUserRole() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserRoleSheet(service: widget.service, users: users, roles: roles),
    );
    if (saved == true) reload();
  }

  Future<void> togglePermission(Map<String, dynamic> permission, bool assigned) async {
    final roleUuid = selectedRoleUuid;
    final permissionUuid = textValue(permission, ['uuid'], fallback: '');
    if (roleUuid == null || roleUuid.isEmpty || permissionUuid.isEmpty) return;
    try {
      if (assigned) {
        await widget.service.removeRolePermission(roleUuid, permissionUuid);
      } else {
        await widget.service.assignRolePermission(roleUuid, permissionUuid);
      }
      reload();
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      route: route,
      actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        if (widget.kind == RbacKind.roles) IconButton(onPressed: createRole, icon: const Icon(Icons.add)),
        if (widget.kind == RbacKind.userRoles) IconButton(onPressed: assignUserRole, icon: const Icon(Icons.add)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (message.isNotEmpty) ...[
            InfoCard(child: Text(message, style: const TextStyle(color: AppColors.danger))),
            const SizedBox(height: 10),
          ],
          FutureBuilder<void>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const LoadingBlock();
              if (snapshot.hasError) return ErrorBlock(message: snapshot.error.toString(), onRetry: reload);
              return switch (widget.kind) {
                RbacKind.roles => _roles(),
                RbacKind.permissions => _permissions(),
                RbacKind.rolePermissions => _rolePermissions(),
                RbacKind.userRoles => _userRoles(),
              };
            },
          ),
        ],
      ),
    );
  }

  Widget _roles() {
    if (roles.isEmpty) return const InfoCard(child: Text('No roles found.'));
    return Column(children: roles.map((role) => _recordCard(
      title: textValue(role, ['name']),
      subtitle: '${textValue(role, ['code'])} / ${textValue(role, ['role_type'])}',
      trailing: '${role['permission_count'] ?? 0} perms',
    )).toList());
  }

  Widget _permissions() {
    final source = groups.isNotEmpty ? groups : permissions;
    if (source.isEmpty) return const InfoCard(child: Text('No permissions found.'));
    return Column(children: source.map((item) {
      final nested = readList(item['permissions']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(textValue(item, ['name']), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(textValue(item, ['code', 'description'])),
              if (nested.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: nested.map((permission) => Chip(label: Text(textValue(permission, ['code', 'name'])))).toList(),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList());
  }

  Widget _rolePermissions() {
    final assigned = rolePermissions.map((item) => textValue(item, ['permission_uuid'], fallback: '')).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedRoleUuid,
          decoration: const InputDecoration(labelText: 'Role'),
          items: roles.map((role) {
            final uuid = textValue(role, ['uuid'], fallback: '');
            return DropdownMenuItem(value: uuid, child: Text(textValue(role, ['name'])));
          }).toList(),
          onChanged: (value) {
            selectedRoleUuid = value;
            reload();
          },
        ),
        const SizedBox(height: 12),
        if (permissions.isEmpty)
          const InfoCard(child: Text('No permissions found.'))
        else
          ...permissions.map((permission) {
            final uuid = textValue(permission, ['uuid'], fallback: '');
            final isAssigned = assigned.contains(uuid);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InfoCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isAssigned,
                  onChanged: (_) => togglePermission(permission, isAssigned),
                  title: Text(textValue(permission, ['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(textValue(permission, ['code'])),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _userRoles() {
    if (userRoles.isEmpty) return const InfoCard(child: Text('No user roles found.'));
    return Column(children: userRoles.map((item) {
      return _recordCard(
        title: textValue(item, ['user_email']),
        subtitle: '${textValue(item, ['role_name'])} / ${textValue(item, ['store_name'], fallback: 'All stores')}',
        trailing: textValue(item, ['is_active']),
        onDelete: () async {
          await widget.service.deleteUserRole(textValue(item, ['uuid'], fallback: ''));
          reload();
        },
      );
    }).toList());
  }

  Widget _recordCard({
    required String title,
    required String subtitle,
    String trailing = '',
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
          subtitle: Text(subtitle),
          trailing: onDelete == null
              ? Text(trailing, style: const TextStyle(fontWeight: FontWeight.w800))
              : IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        ),
      ),
    );
  }
}

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.service});

  final RbacService service;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  String error = '';

  Future<void> save() async {
    try {
      await widget.service.createRole({
        'name': name.text.trim(),
        'code': code.text.trim(),
        'description': description.text.trim(),
        'role_type': 'CUSTOM',
        'organization': null,
        'store': null,
        'display_order': 0,
        'is_default': false,
        'permissions': <String>[],
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Add Role',
      error: error,
      onSave: save,
      children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
        const SizedBox(height: 10),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
      ],
    );
  }
}

class _UserRoleSheet extends StatefulWidget {
  const _UserRoleSheet({required this.service, required this.users, required this.roles});

  final RbacService service;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> roles;

  @override
  State<_UserRoleSheet> createState() => _UserRoleSheetState();
}

class _UserRoleSheetState extends State<_UserRoleSheet> {
  int? user;
  int? role;
  final store = TextEditingController();
  String error = '';

  Future<void> save() async {
    if (user == null || role == null) {
      setState(() => error = 'Select user and role.');
      return;
    }
    try {
      await widget.service.assignUserRole(user: user!, role: role!, store: int.tryParse(store.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Assign User Role',
      error: error,
      onSave: save,
      children: [
        DropdownButtonFormField<int>(
          initialValue: user,
          decoration: const InputDecoration(labelText: 'User'),
          items: widget.users.map((item) {
            return DropdownMenuItem(value: int.tryParse(item['id'].toString()), child: Text(textValue(item, ['email', 'display_name'])));
          }).toList(),
          onChanged: (value) => setState(() => user = value),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Role'),
          items: widget.roles.map((item) {
            return DropdownMenuItem(value: int.tryParse(item['id'].toString()), child: Text(textValue(item, ['name'])));
          }).toList(),
          onChanged: (value) => setState(() => role = value),
        ),
        const SizedBox(height: 10),
        TextField(controller: store, decoration: const InputDecoration(labelText: 'Store ID (optional)'), keyboardType: TextInputType.number),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.error,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final String error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...children,
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(error, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: onSave, child: const Text('Save')),
        ],
      ),
    );
  }
}
