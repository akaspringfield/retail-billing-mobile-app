import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../settings/presentation/settings_controller.dart';
import 'auth_controller.dart';

enum _LoginViewState { normal, loading, error, offline }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepRegisterActive = true;
  _LoginViewState _viewState = _LoginViewState.normal;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _viewState = _LoginViewState.loading);
    TextInput.finishAutofillContext();
    final success = await ref.read(authControllerProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (!mounted || success) return;
    setState(() => _viewState = _LoginViewState.error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final isLoading = auth.isLoading || _viewState == _LoginViewState.loading;
    final showError =
        auth.errorMessage != null || _viewState == _LoginViewState.error;
    final showOffline = _viewState == _LoginViewState.offline && !showError;

    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 538),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StateSwitcher(
                        value: _viewState,
                        onChanged: (value) {
                          setState(() => _viewState = value);
                        },
                      ),
                      const SizedBox(height: 36),
                      const _TerminalHeader(),
                      const SizedBox(height: 22),
                      if (showError) ...[
                        _StatusBanner(
                          icon: Icons.error_outline,
                          title: 'Authentication Failed',
                          message: auth.errorMessage ??
                              'Invalid cashier ID or PIN. Check credentials and try again.',
                          backgroundColor: const Color(0xffffdad6),
                          foregroundColor: AppTheme.danger,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (showOffline) ...[
                        const _StatusBanner(
                          icon: Icons.cloud_off_outlined,
                          title: 'POS Server Unreachable',
                          message:
                              'Backend connection is offline. Check network and API URL.',
                          backgroundColor: Color(0xffd5e0f8),
                          foregroundColor: Color(0xff545f73),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _LoginCard(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        keepRegisterActive: _keepRegisterActive,
                        isLoading: isLoading,
                        apiBaseUrl: settings.apiBaseUrl,
                        onTogglePassword: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        onKeepRegisterChanged: (value) {
                          setState(() => _keepRegisterActive = value);
                        },
                        onSubmit: _submit,
                        onEditApiUrl: () => _editApiUrl(settings),
                      ),
                      const SizedBox(height: 28),
                      _Footer(apiBaseUrl: settings.apiBaseUrl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editApiUrl(AppSettings settings) async {
    final controller = TextEditingController(text: settings.apiBaseUrl);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Settings'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API base URL',
            helperText:
                'Example: https://flint-elevation-wolverine.ngrok-free.dev/api',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (next == null || next.trim().isEmpty) return;
    await ref.read(settingsControllerProvider.notifier).update(
          settings.copyWith(apiBaseUrl: next.trim()),
        );
  }
}

class _StateSwitcher extends StatelessWidget {
  const _StateSwitcher({
    required this.value,
    required this.onChanged,
  });

  final _LoginViewState value;
  final ValueChanged<_LoginViewState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xffd3e4fe),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatePill(
            label: 'Normal',
            selected: value == _LoginViewState.normal,
            onTap: () => onChanged(_LoginViewState.normal),
          ),
          _StatePill(
            label: 'Loading',
            selected: value == _LoginViewState.loading,
            onTap: () => onChanged(_LoginViewState.loading),
          ),
          _StatePill(
            label: 'Error',
            selected: value == _LoginViewState.error,
            onTap: () => onChanged(_LoginViewState.error),
          ),
          _StatePill(
            label: 'Offline',
            selected: value == _LoginViewState.offline,
            onTap: () => onChanged(_LoginViewState.offline),
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppTheme.primary : const Color(0xff545f73),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.point_of_sale,
                color: Colors.white,
                size: 44,
              ),
            ),
            Positioned(
              right: -7,
              bottom: -7,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xff008f3f),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'BAPU\'S OVEN POS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff0b1c30),
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xffd5e0f8).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 18, color: Color(0xff545f73)),
              SizedBox(width: 7),
              Text(
                'STORE #104 - TERMINAL 04',
                style: TextStyle(
                  color: Color(0xff586377),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Sign in to start cashier shift & open register',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff545f73),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.keepRegisterActive,
    required this.isLoading,
    required this.apiBaseUrl,
    required this.onTogglePassword,
    required this.onKeepRegisterChanged,
    required this.onSubmit,
    required this.onEditApiUrl,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool keepRegisterActive;
  final bool isLoading;
  final String apiBaseUrl;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onKeepRegisterChanged;
  final VoidCallback onSubmit;
  final VoidCallback onEditApiUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputLabel(
            label: 'Cashier ID / Email',
            trailing: TextButton(
              onPressed: onEditApiUrl,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'terminal auth',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            enabled: !isLoading,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: _terminalInputDecoration(
              hintText: 'akash@bapusoven.com',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Cashier ID or email is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          const _InputLabel(
            label: 'Security PIN / Password',
            trailing: Text(
              '6-digit PIN',
              style: TextStyle(
                color: Color(0xff545f73),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordController,
            enabled: !isLoading,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: _terminalInputDecoration(
              hintText: 'Enter terminal password',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xff545f73),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Checkbox(
                value: keepRegisterActive,
                onChanged: isLoading
                    ? null
                    : (value) => onKeepRegisterChanged(value ?? false),
                activeColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              const Expanded(
                child: Text(
                  'Keep register active',
                  style: TextStyle(
                    color: Color(0xff0b1c30),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isLoading ? null : () {},
                icon: const Icon(Icons.support_agent_outlined, size: 18),
                label: const Text('Manager PIN'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.72),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: AppTheme.primary.withValues(alpha: 0.3),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login, size: 24),
              label: Text(
                isLoading
                    ? 'Verifying Shift & Register...'
                    : 'Sign In to Terminal',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _ApiUrlButton(apiBaseUrl: apiBaseUrl, onPressed: onEditApiUrl),
          const SizedBox(height: 22),
          const _ShiftScheduleCard(),
        ],
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({
    required this.label,
    required this.trailing,
  });

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff545f73),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

InputDecoration _terminalInputDecoration({
  required String hintText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(prefixIcon, color: const Color(0xff545f73)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xfff8f9ff),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xffe5eeff)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xffe5eeff)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
  );
}

class _ApiUrlButton extends StatelessWidget {
  const _ApiUrlButton({
    required this.apiBaseUrl,
    required this.onPressed,
  });

  final String apiBaseUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: Color(0xffd3e4fe)),
        foregroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.tune, size: 22),
      label: Expanded(
        child: Text(
          apiBaseUrl,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ShiftScheduleCard extends StatelessWidget {
  const _ShiftScheduleCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'SHIFT SCHEDULE',
                style: TextStyle(
                  color: Color(0xff545f73),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              'Ready for Opening',
              style: TextStyle(
                color: Color(0xff008f3f),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffeff4ff),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Morning Shift (A)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff0b1c30),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '08:00 AM - 04:00 PM',
                      style: TextStyle(
                        color: Color(0xff545f73),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xffd5e0f8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LANE #4',
                  style: TextStyle(
                    color: Color(0xff586377),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: foregroundColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _OnlineDot(),
            SizedBox(width: 9),
            Text(
              'Cloud POS Realtime Sync: OK',
              style: TextStyle(
                color: Color(0xff545f73),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: const [
            Text('Build v2.4.1 (rev 840)', style: _footerTextStyle),
            Text('-', style: _footerTextStyle),
            Text('PCI-PTS 5.X Certified', style: _footerTextStyle),
            Text('-', style: _footerTextStyle),
            Text('BAPU\'S OVEN', style: _footerTextStyle),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          apiBaseUrl,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xff8b95a5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_reset, size: 18),
          label: const Text('Supervisor Manual Override Key'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xff545f73)),
        ),
      ],
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xff008f3f),
        shape: BoxShape.circle,
      ),
    );
  }
}

const _footerTextStyle = TextStyle(
  color: Color(0xff8b95a5),
  fontSize: 13,
  fontWeight: FontWeight.w700,
);
