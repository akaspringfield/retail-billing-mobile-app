import 'package:flutter/material.dart';

import '../data_utils.dart';
import '../people_service.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

enum PeopleKind { customers, suppliers, users }

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.service, required this.kind});

  final PeopleService service;
  final PeopleKind kind;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> future = load();

  String get title => switch (widget.kind) {
        PeopleKind.customers => 'Customers',
        PeopleKind.suppliers => 'Suppliers',
        PeopleKind.users => 'Users',
      };

  String get route => switch (widget.kind) {
        PeopleKind.customers => '/customers',
        PeopleKind.suppliers => '/suppliers',
        PeopleKind.users => '/users',
      };

  Future<List<Map<String, dynamic>>> load() {
    return switch (widget.kind) {
      PeopleKind.customers => widget.service.customers(),
      PeopleKind.suppliers => widget.service.suppliers(),
      PeopleKind.users => widget.service.users(),
    };
  }

  void reload() => setState(() => future = load());

  Future<void> openCreate() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePersonSheet(kind: widget.kind, service: widget.service),
    );
    if (saved == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      route: route,
      actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: openCreate, icon: const Icon(Icons.add)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const LoadingBlock();
              if (snapshot.hasError) return ErrorBlock(message: snapshot.error.toString(), onRetry: reload);

              final query = search.text.trim().toLowerCase();
              final records = (snapshot.data ?? []).where((record) {
                if (query.isEmpty) return true;
                return record.values.any((value) => value.toString().toLowerCase().contains(query));
              }).toList();

              if (records.isEmpty) {
                return const InfoCard(child: Text('No records found.'));
              }

              return Column(children: records.map(_recordTile).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> record) {
    final isUser = widget.kind == PeopleKind.users;
    final primary = isUser
        ? textValue(record, ['display_name', 'username', 'email'])
        : textValue(record, ['name', 'display_name']);
    final secondary = isUser
        ? textValue(record, ['email', 'mobile_number'])
        : textValue(record, ['phone', 'email', 'contact_person']);
    final status = isUser
        ? textValue(record, ['status', 'employment_status'], fallback: '')
        : textValue(record, ['current_balance', 'status'], fallback: '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.page,
              foregroundColor: AppColors.primary,
              child: Text(primary.isEmpty ? '?' : primary[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(primary, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Text(status, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _CreatePersonSheet extends StatefulWidget {
  const _CreatePersonSheet({required this.kind, required this.service});

  final PeopleKind kind;
  final PeopleService service;

  @override
  State<_CreatePersonSheet> createState() => _CreatePersonSheetState();
}

class _CreatePersonSheetState extends State<_CreatePersonSheet> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  String error = '';
  bool saving = false;

  String get title => switch (widget.kind) {
        PeopleKind.customers => 'Add Customer',
        PeopleKind.suppliers => 'Add Supplier',
        PeopleKind.users => 'Add User',
      };

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Name is required.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      if (widget.kind == PeopleKind.customers) {
        await widget.service.createCustomer({
          'name': name.text.trim(),
          'customer_type': 'RETAIL',
          'status': 'ACTIVE',
          'phone': phone.text.trim(),
          'alternate_phone': '',
          'email': email.text.trim(),
          'gst_number': '',
          'pan_number': '',
          'postal_code': '',
          'address': '',
          'credit_limit': '0',
          'opening_balance': '0',
          'payment_terms': 0,
          'remarks': '',
          'is_active': true,
        });
      } else if (widget.kind == PeopleKind.suppliers) {
        await widget.service.createSupplier({
          'name': name.text.trim(),
          'contact_person': name.text.trim(),
          'phone': phone.text.trim(),
          'alternate_phone': '',
          'email': email.text.trim(),
          'gst_number': '',
          'pan_number': '',
          'postal_code': '',
          'address': '',
          'credit_limit': '0',
          'opening_balance': '0',
          'payment_terms': 0,
          'remarks': '',
          'is_active': true,
        });
      } else {
        final parts = name.text.trim().split(RegExp(r'\s+'));
        await widget.service.createUser({
          'email': email.text.trim(),
          'username': email.text.trim(),
          'password': password.text.trim(),
          'first_name': parts.first,
          'last_name': parts.length > 1 ? parts.sublist(1).join(' ') : '',
          'display_name': name.text.trim(),
          'organization': null,
          'store': null,
          'store_access_type': 'ALL',
          'employee_code': null,
          'mobile_number': phone.text.trim(),
          'direct_phone': '',
          'employment_status': 'ACTIVE',
          'login_permission': true,
          'is_guest_user': false,
          'status': 'ACTIVE',
          'is_staff': false,
          'is_active': true,
          'active_from': null,
          'active_till': null,
          'language': 'en',
          'timezone': 'Asia/Kolkata',
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
          if (widget.kind == PeopleKind.users) ...[
            const SizedBox(height: 10),
            TextField(controller: password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(error, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save')),
        ],
      ),
    );
  }
}
