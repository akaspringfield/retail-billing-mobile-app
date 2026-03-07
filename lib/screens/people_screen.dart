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
      builder: (_) =>
          _CreatePersonSheet(kind: widget.kind, service: widget.service),
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
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingBlock();
              if (snapshot.hasError)
                return ErrorBlock(
                    message: snapshot.error.toString(), onRetry: reload);

              final query = search.text.trim().toLowerCase();
              final records = (snapshot.data ?? []).where((record) {
                if (query.isEmpty) return true;
                return record.values.any(
                    (value) => value.toString().toLowerCase().contains(query));
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
                  Text(primary,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Text(status,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.muted)),
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
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final displayName = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final alternatePhone = TextEditingController();
  final directPhone = TextEditingController();
  final password = TextEditingController();
  final contactPerson = TextEditingController();
  final gstNumber = TextEditingController();
  final panNumber = TextEditingController();
  final postalCode = TextEditingController();
  final address = TextEditingController();
  final creditLimit = TextEditingController(text: '0.00');
  final openingBalance = TextEditingController(text: '0.00');
  final paymentTerms = TextEditingController(text: '0');
  final remarks = TextEditingController();
  final employeeCode = TextEditingController();

  late final Future<List<Map<String, dynamic>>> storesFuture;
  int? storeId;
  String customerType = 'INDIVIDUAL';
  String customerStatus = 'ACTIVE';
  String storeAccessType = 'PARTICULAR';
  String employmentStatus = 'EMPLOYEE';
  String userStatus = 'ACTIVE';
  bool isActive = true;
  bool loginPermission = true;
  bool isStaff = false;
  bool isGuest = false;
  DateTime? activeFrom;
  DateTime? activeTill;
  String error = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    storesFuture = widget.service.stores();
  }

  String get title => switch (widget.kind) {
        PeopleKind.customers => 'Add Customer',
        PeopleKind.suppliers => 'Add Supplier',
        PeopleKind.users => 'Add User',
      };

  String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> save(List<Map<String, dynamic>> stores) async {
    Map<String, dynamic>? selectedStore;
    for (final store in stores) {
      if (store['id'] == storeId) selectedStore = store;
    }
    selectedStore ??= stores.isEmpty ? null : stores.first;
    final organizationId = selectedStore?['organization'];
    if (organizationId == null) {
      setState(() => error = 'Organization/store context is not available.');
      return;
    }
    if (widget.kind != PeopleKind.users && name.text.trim().isEmpty) {
      setState(() => error = 'Name is required.');
      return;
    }
    if (widget.kind == PeopleKind.users) {
      if (email.text.trim().isEmpty || firstName.text.trim().isEmpty) {
        setState(() => error = 'Email and first name are required.');
        return;
      }
      if (password.text.length < 8) {
        setState(() => error = 'Password must be at least 8 characters.');
        return;
      }
      if (storeId == null) {
        setState(() => error = 'Select a default store.');
        return;
      }
      if (activeFrom != null &&
          activeTill != null &&
          activeTill!.isBefore(activeFrom!)) {
        setState(
            () => error = 'Active till date must be after active from date.');
        return;
      }
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      if (widget.kind == PeopleKind.customers) {
        await widget.service.createCustomer({
          'organization': organizationId,
          'name': name.text.trim(),
          'customer_type': customerType,
          'status': customerStatus,
          'phone': phone.text.trim(),
          'alternate_phone': '',
          'email': email.text.trim().toLowerCase(),
          'gst_number': gstNumber.text.replaceAll(' ', '').toUpperCase(),
          'pan_number': panNumber.text.replaceAll(' ', '').toUpperCase(),
          'postal_code': '',
          'address': address.text.trim(),
          'credit_limit': creditLimit.text.trim(),
          'opening_balance': '0.00',
          'payment_terms': 0,
          'remarks': '',
          'is_active': true,
        });
      } else if (widget.kind == PeopleKind.suppliers) {
        await widget.service.createSupplier({
          'organization': organizationId,
          'name': name.text.trim(),
          'contact_person': contactPerson.text.trim(),
          'phone': phone.text.trim(),
          'alternate_phone': alternatePhone.text.trim(),
          'email': email.text.trim().toLowerCase(),
          'gst_number': gstNumber.text.replaceAll(' ', '').toUpperCase(),
          'pan_number': panNumber.text.replaceAll(' ', '').toUpperCase(),
          'postal_code': postalCode.text.trim(),
          'address': address.text.trim(),
          'credit_limit': creditLimit.text.trim(),
          'opening_balance': openingBalance.text.trim(),
          'payment_terms': int.tryParse(paymentTerms.text.trim()) ?? 0,
          'remarks': remarks.text.trim(),
          'is_active': isActive,
        });
      } else {
        final display = displayName.text.trim().isNotEmpty
            ? displayName.text.trim()
            : '${firstName.text.trim()} ${lastName.text.trim()}'.trim();
        await widget.service.createUser({
          'email': email.text.trim().toLowerCase(),
          'username': username.text.trim().isEmpty
              ? email.text.trim().toLowerCase()
              : username.text.trim(),
          'password': password.text,
          'first_name': firstName.text.trim(),
          'last_name': lastName.text.trim(),
          'display_name': display.isEmpty ? email.text.trim() : display,
          'organization': organizationId,
          'store': storeId,
          'store_access_type': storeAccessType,
          'employee_code': employeeCode.text.trim().isEmpty
              ? null
              : employeeCode.text.trim(),
          'mobile_number': phone.text.trim(),
          'direct_phone': directPhone.text.trim(),
          'employment_status': employmentStatus,
          'login_permission': loginPermission,
          'is_guest_user': isGuest,
          'status': userStatus,
          'is_staff': isStaff,
          'is_active': isActive,
          'active_from': _date(activeFrom),
          'active_till': _date(activeTill),
          'language': 'en',
          'timezone': 'Asia/Kolkata',
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: storesFuture,
      builder: (context, snapshot) {
        final stores = snapshot.data ?? const <Map<String, dynamic>>[];
        storeId ??= stores.isEmpty ? null : stores.first['id'] as int?;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator()
                else if (snapshot.hasError)
                  Text(snapshot.error.toString(),
                      style: const TextStyle(color: AppColors.danger))
                else ...[
                  if (widget.kind == PeopleKind.users)
                    ..._userFields(stores)
                  else if (widget.kind == PeopleKind.suppliers)
                    ..._supplierFields()
                  else
                    ..._customerFields(),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(error,
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: saving ? null : () => save(stores),
                    child: Text(saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _customerFields() => [
        _field(name, 'Name'),
        _dropdown(
            'Type',
            customerType,
            const {'INDIVIDUAL': 'Individual', 'BUSINESS': 'Business'},
            (value) => customerType = value),
        _dropdown(
            'Status',
            customerStatus,
            const {
              'ACTIVE': 'Active',
              'INACTIVE': 'Inactive',
              'BLOCKED': 'Blocked'
            },
            (value) => customerStatus = value),
        _field(phone, 'Phone', type: TextInputType.phone),
        _field(email, 'Email', type: TextInputType.emailAddress),
        _field(gstNumber, 'GST Number', caps: TextCapitalization.characters),
        _field(panNumber, 'PAN Number', caps: TextCapitalization.characters),
        _field(creditLimit, 'Credit Limit',
            type: const TextInputType.numberWithOptions(decimal: true)),
        _field(address, 'Address', lines: 3),
      ];

  List<Widget> _supplierFields() => [
        _field(name, 'Name'),
        _field(contactPerson, 'Contact Person'),
        _field(phone, 'Phone', type: TextInputType.phone),
        _field(alternatePhone, 'Alternate Phone', type: TextInputType.phone),
        _field(email, 'Email', type: TextInputType.emailAddress),
        _field(gstNumber, 'GST Number', caps: TextCapitalization.characters),
        _field(panNumber, 'PAN Number', caps: TextCapitalization.characters),
        _field(creditLimit, 'Credit Limit',
            type: const TextInputType.numberWithOptions(decimal: true)),
        _field(openingBalance, 'Opening Balance',
            type: const TextInputType.numberWithOptions(decimal: true)),
        _field(paymentTerms, 'Payment Terms (days)',
            type: TextInputType.number),
        _field(postalCode, 'Postal Code'),
        _dropdown(
            'Status',
            isActive ? 'ACTIVE' : 'INACTIVE',
            const {'ACTIVE': 'Active', 'INACTIVE': 'Inactive'},
            (value) => isActive = value == 'ACTIVE'),
        _field(address, 'Address', lines: 3),
        _field(remarks, 'Remarks', lines: 3),
      ];

  List<Widget> _userFields(List<Map<String, dynamic>> stores) => [
        _field(email, 'Email', type: TextInputType.emailAddress),
        _field(username, 'Username', hint: 'Defaults to email'),
        _field(password, 'Password', obscure: true),
        _field(firstName, 'First Name'),
        _field(lastName, 'Last Name'),
        _field(displayName, 'Display Name'),
        _dropdown(
            'Store Access',
            storeAccessType,
            const {'PARTICULAR': 'Particular store', 'ALL': 'All stores'},
            (value) => storeAccessType = value),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int>(
            key: ValueKey(storeId),
            initialValue: storeId,
            decoration: const InputDecoration(labelText: 'Store'),
            items: stores
                .map((store) => DropdownMenuItem<int>(
                    value: store['id'] as int?,
                    child: Text(textValue(store, ['name']))))
                .toList(),
            onChanged: (value) => setState(() => storeId = value),
          ),
        ),
        _dateField('Active From', activeFrom, (value) => activeFrom = value),
        _dateField('Active Till', activeTill, (value) => activeTill = value),
        _field(employeeCode, 'Employee Code'),
        _dropdown(
            'Employment',
            employmentStatus,
            const {
              'OWNER': 'Owner',
              'EMPLOYEE': 'Employee',
              'CONTRACT': 'Contract',
              'TEMPORARY': 'Temporary'
            },
            (value) => employmentStatus = value),
        _field(phone, 'Mobile', type: TextInputType.phone),
        _field(directPhone, 'Direct Phone', type: TextInputType.phone),
        _dropdown(
            'Status',
            userStatus,
            const {
              'PENDING': 'Pending',
              'ACTIVE': 'Active',
              'INACTIVE': 'Inactive',
              'SUSPENDED': 'Suspended',
              'LOCKED': 'Locked',
              'REJECTED': 'Rejected'
            },
            (value) => userStatus = value),
        _toggle('Login allowed', loginPermission,
            (value) => loginPermission = value),
        _toggle('Staff', isStaff, (value) => isStaff = value),
        _toggle('Guest', isGuest, (value) => isGuest = value),
        _toggle('Active', isActive, (value) => isActive = value),
      ];

  Widget _field(TextEditingController controller, String label,
          {TextInputType? type,
          int lines = 1,
          bool obscure = false,
          String? hint,
          TextCapitalization caps = TextCapitalization.none}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: type,
          maxLines: lines,
          obscureText: obscure,
          textCapitalization: caps,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  Widget _dropdown(String label, String value, Map<String, String> options,
          ValueChanged<String> changed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: options.entries
              .map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) setState(() => changed(next));
          },
        ),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> changed) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (next) => setState(() => changed(next)),
      );

  Widget _dateField(
          String label, DateTime? value, ValueChanged<DateTime?> changed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () async {
            final next = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (next != null) setState(() => changed(next));
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(_date(value) ?? 'Not set'),
          ),
        ),
      );
}
