import 'package:flutter/material.dart';

import '../data_utils.dart';
import '../people_service.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key, required this.service});

  final PeopleService service;

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final search = TextEditingController();
  String status = '';
  String type = '';
  late Future<List<Map<String, dynamic>>> future = widget.service.allStores();

  void reload() => setState(() => future = widget.service.allStores());

  Future<void> openForm([Map<String, dynamic>? store]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _StoreForm(service: widget.service, store: store),
    );
    if (saved == true) reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Stores',
      route: '/stores',
      actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: reload,
            icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'Add store',
            onPressed: () => openForm(),
            icon: const Icon(Icons.add)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stores', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search stores'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _filter(
                      'Status',
                      status,
                      const {
                        '': 'All',
                        'ACTIVE': 'Active',
                        'INACTIVE': 'Inactive',
                        'CLOSED': 'Closed'
                      },
                      (v) => setState(() => status = v))),
              const SizedBox(width: 10),
              Expanded(
                  child: _filter(
                      'Type',
                      type,
                      const {
                        '': 'All',
                        'MAIN': 'Main',
                        'BRANCH': 'Branch',
                        'WAREHOUSE': 'Warehouse'
                      },
                      (v) => setState(() => type = v))),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingBlock();
              if (snapshot.hasError)
                return ErrorBlock(
                    message: snapshot.error.toString(), onRetry: reload);
              final query = search.text.trim().toLowerCase();
              final stores = (snapshot.data ?? []).where((item) {
                final matchesQuery = query.isEmpty ||
                    item.values
                        .any((value) => '$value'.toLowerCase().contains(query));
                return matchesQuery &&
                    (status.isEmpty || item['status'] == status) &&
                    (type.isEmpty || item['store_type'] == type);
              }).toList();
              if (stores.isEmpty)
                return const InfoCard(child: Text('No stores found.'));
              return Column(children: stores.map(_storeCard).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _storeCard(Map<String, dynamic> store) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => openForm(store),
          borderRadius: BorderRadius.circular(8),
          child: InfoCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.storefront_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(textValue(store, ['display_name', 'name']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text('${textValue(store, [
                            'code'
                          ])} / ${_label(textValue(store, ['store_type']))}'),
                      Text(textValue(store, ['city', 'address'], fallback: ''),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _status(textValue(store, ['status'])),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );

  Widget _status(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: value == 'ACTIVE'
              ? const Color(0xFFE5F6EA)
              : const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_label(value),
            style: TextStyle(
                color: value == 'ACTIVE'
                    ? AppColors.success
                    : const Color(0xFF8A5B00),
                fontWeight: FontWeight.w800)),
      );

  Widget _filter(String label, String value, Map<String, String> options,
          ValueChanged<String> changed) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map((entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: (next) {
          if (next != null) changed(next);
        },
      );

  String _label(String value) => value
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _StoreForm extends StatefulWidget {
  const _StoreForm({required this.service, this.store});

  final PeopleService service;
  final Map<String, dynamic>? store;

  @override
  State<_StoreForm> createState() => _StoreFormState();
}

class _StoreLookups {
  const _StoreLookups(
      this.organizations, this.users, this.countries, this.states, this.cities);
  final List<Map<String, dynamic>> organizations;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> states;
  final List<Map<String, dynamic>> cities;
}

class _StoreFormState extends State<_StoreForm> {
  late final name = TextEditingController(
      text: textValue(widget.store ?? {}, ['name'], fallback: ''));
  late final displayName = TextEditingController(
      text: textValue(widget.store ?? {}, ['display_name'], fallback: ''));
  late final phone = TextEditingController(
      text: textValue(widget.store ?? {}, ['phone'], fallback: ''));
  late final email = TextEditingController(
      text: textValue(widget.store ?? {}, ['email'], fallback: ''));
  late final address = TextEditingController(
      text: textValue(widget.store ?? {}, ['address'], fallback: ''));
  late final postalCode = TextEditingController(
      text: textValue(widget.store ?? {}, ['postal_code'], fallback: ''));
  late final timezone = TextEditingController(
      text: textValue(widget.store ?? {}, ['timezone'],
          fallback: 'Asia/Kolkata'));
  late final currency = TextEditingController(
      text: textValue(widget.store ?? {}, ['currency'], fallback: 'INR'));
  late final openingDate = TextEditingController(
      text: textValue(widget.store ?? {}, ['opening_date'], fallback: ''));
  late final openingTime = TextEditingController(
      text: textValue(widget.store ?? {}, ['opening_time'], fallback: ''));
  late final closingTime = TextEditingController(
      text: textValue(widget.store ?? {}, ['closing_time'], fallback: ''));
  late final receiptHeader = TextEditingController(
      text: textValue(widget.store ?? {}, ['receipt_header'], fallback: ''));
  late final receiptFooter = TextEditingController(
      text: textValue(widget.store ?? {}, ['receipt_footer'], fallback: ''));
  late String storeType =
      textValue(widget.store ?? {}, ['store_type'], fallback: 'BRANCH');
  late String status =
      textValue(widget.store ?? {}, ['status'], fallback: 'ACTIVE');
  late String country =
      textValue(widget.store ?? {}, ['country'], fallback: 'India');
  late String state = textValue(widget.store ?? {}, ['state'], fallback: '');
  late String city = textValue(widget.store ?? {}, ['city'], fallback: '');
  late int? organization = _id(widget.store?['organization']);
  late int? manager = _id(widget.store?['manager']);
  late bool allowNegative = widget.store?['allow_negative_stock'] == true;
  late bool headOffice = widget.store?['is_head_office'] == true;
  late bool isDefault = widget.store?['is_default'] == true;
  late bool isActive = widget.store?['is_active'] ?? true;
  late final Future<_StoreLookups> lookups = _load();
  bool saving = false;
  String error = '';

  Future<_StoreLookups> _load() async {
    final results = await Future.wait([
      widget.service.organizations(),
      widget.service.users(),
      widget.service.masterRecords('countries'),
      widget.service.masterRecords('states'),
      widget.service.masterRecords('cities'),
    ]);
    return _StoreLookups(
        results[0], results[1], results[2], results[3], results[4]);
  }

  int? _id(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  @override
  Widget build(BuildContext context) => FutureBuilder<_StoreLookups>(
        future: lookups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Padding(
                padding: EdgeInsets.all(40), child: LoadingBlock());
          if (snapshot.hasError)
            return Padding(
                padding: const EdgeInsets.all(18),
                child: ErrorBlock(
                    message: snapshot.error.toString(),
                    onRetry: () => Navigator.pop(context)));
          final data = snapshot.data!;
          organization ??= data.organizations.isNotEmpty
              ? _id(data.organizations.first['id'])
              : null;
          final states = data.states
              .where((item) =>
                  country.isEmpty ||
                  textValue(item, ['country_name'], fallback: '') == country ||
                  _id(item['country']) == _selectedId(data.countries, country))
              .toList();
          final cities = data.cities
              .where((item) =>
                  state.isEmpty ||
                  textValue(item, ['state_name'], fallback: '') == state ||
                  _id(item['state']) == _selectedId(data.states, state))
              .toList();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          widget.store == null ? 'New Store' : 'Edit Store',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ]),
                const SizedBox(height: 12),
                _intDropdown('Organization', organization, data.organizations,
                    (v) => setState(() => organization = v)),
                _field(name, 'Name'),
                _field(displayName, 'Display Name'),
                _stringDropdown(
                    'Type',
                    storeType,
                    const {
                      'MAIN': 'Main Store',
                      'BRANCH': 'Branch Store',
                      'WAREHOUSE': 'Warehouse'
                    },
                    (v) => setState(() => storeType = v)),
                _stringDropdown(
                    'Status',
                    status,
                    const {
                      'ACTIVE': 'Active',
                      'INACTIVE': 'Inactive',
                      'CLOSED': 'Closed'
                    },
                    (v) => setState(() => status = v)),
                _intDropdown('Manager', manager, data.users,
                    (v) => setState(() => manager = v),
                    optional: true),
                _field(email, 'Email', type: TextInputType.emailAddress),
                _field(phone, 'Phone', type: TextInputType.phone),
                _nameDropdown(
                    'Country',
                    country,
                    data.countries,
                    (v) => setState(() {
                          country = v;
                          state = '';
                          city = '';
                        })),
                _nameDropdown(
                    'State',
                    state,
                    states,
                    (v) => setState(() {
                          state = v;
                          city = '';
                        })),
                _nameDropdown(
                    'City', city, cities, (v) => setState(() => city = v)),
                _field(postalCode, 'Postal Code'),
                _field(address, 'Address', lines: 3),
                _field(timezone, 'Timezone'),
                _field(currency, 'Currency'),
                _field(openingDate, 'Opening Date (YYYY-MM-DD)'),
                Row(children: [
                  Expanded(child: _field(openingTime, 'Opens At (HH:MM)')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(closingTime, 'Closes At (HH:MM)'))
                ]),
                _field(receiptHeader, 'Receipt Header', lines: 2),
                _field(receiptFooter, 'Receipt Footer', lines: 2),
                _toggle('Head office', headOffice, (v) => headOffice = v),
                _toggle('Default store', isDefault, (v) => isDefault = v),
                _toggle('Allow negative stock', allowNegative,
                    (v) => allowNegative = v),
                _toggle('Active', isActive, (v) => isActive = v),
                if (error.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(error,
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700))),
                FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save Store')),
                if (widget.store != null)
                  TextButton.icon(
                      onPressed: saving ? null : delete,
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      label: const Text('Delete Store',
                          style: TextStyle(color: AppColors.danger))),
              ],
            ),
          );
        },
      );

  int? _selectedId(List<Map<String, dynamic>> records, String name) {
    for (final item in records) {
      if (textValue(item, ['name', 'display_name']) == name)
        return _id(item['id']);
    }
    return null;
  }

  Future<void> save() async {
    if (organization == null ||
        name.text.trim().isEmpty ||
        displayName.text.trim().isEmpty) {
      setState(
          () => error = 'Organization, name, and display name are required.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final payload = <String, dynamic>{
      'organization': organization,
      'name': name.text.trim(),
      'display_name': displayName.text.trim(),
      'store_type': storeType,
      'status': status,
      'manager': manager,
      'email': email.text.trim().toLowerCase(),
      'phone': phone.text.trim(),
      'country': country,
      'state': state,
      'city': city,
      'postal_code': postalCode.text.trim(),
      'address': address.text.trim(),
      'timezone': timezone.text.trim(),
      'currency': currency.text.trim(),
      'opening_date':
          openingDate.text.trim().isEmpty ? null : openingDate.text.trim(),
      'opening_time':
          openingTime.text.trim().isEmpty ? null : openingTime.text.trim(),
      'closing_time':
          closingTime.text.trim().isEmpty ? null : closingTime.text.trim(),
      'receipt_header': receiptHeader.text.trim(),
      'receipt_footer': receiptFooter.text.trim(),
      'allow_negative_stock': allowNegative,
      'is_head_office': headOffice,
      'is_default': isDefault,
      'is_active': isActive,
    };
    try {
      final uuid = textValue(widget.store ?? {}, ['uuid'], fallback: '');
      if (uuid.isEmpty) {
        await widget.service.createStore(payload);
      } else {
        payload['code'] = textValue(widget.store!, ['code'], fallback: '');
        await widget.service.updateStore(uuid, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(() {
          saving = false;
          error = '$exception';
        });
    }
  }

  Future<void> delete() async {
    final uuid = textValue(widget.store ?? {}, ['uuid'], fallback: '');
    if (uuid.isEmpty) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Delete store'),
                content: Text('Delete ${name.text}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true) return;
    try {
      await widget.service.deleteStore(uuid);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    }
  }

  Widget _field(TextEditingController controller, String label,
          {int lines = 1, TextInputType? type}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: controller,
              maxLines: lines,
              keyboardType: type,
              decoration: InputDecoration(labelText: label)));

  Widget _stringDropdown(String label, String value,
          Map<String, String> options, ValueChanged<String> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: options.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) changed(v);
              }));

  Widget _intDropdown(String label, int? value,
          List<Map<String, dynamic>> records, ValueChanged<int?> changed,
          {bool optional = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int?>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: [
                if (optional)
                  const DropdownMenuItem(value: null, child: Text('None')),
                ...records.map((item) => DropdownMenuItem(
                    value: _id(item['id']),
                    child: Text(
                        textValue(item, ['display_name', 'name', 'email']))))
              ],
              onChanged: changed));

  Widget _nameDropdown(String label, String value,
          List<Map<String, dynamic>> records, ValueChanged<String> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
              initialValue: records.any((item) =>
                      textValue(item, ['name', 'display_name']) == value)
                  ? value
                  : null,
              decoration: InputDecoration(labelText: label),
              items: records.map((item) {
                final name = textValue(item, ['name', 'display_name']);
                return DropdownMenuItem(value: name, child: Text(name));
              }).toList(),
              onChanged: (v) {
                if (v != null) changed(v);
              }));

  Widget _toggle(String label, bool value, ValueChanged<bool> changed) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (v) => setState(() => changed(v)));
}
