import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../env.dart';
import '../theme.dart';

class BackendStatusDot extends StatefulWidget {
  const BackendStatusDot({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  State<BackendStatusDot> createState() => _BackendStatusDotState();
}

class _BackendStatusDotState extends State<BackendStatusDot> {
  bool? connected;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    check();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => check());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(Uri.parse(AppEnv.apiBaseUrl)).timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(const Duration(seconds: 3));
      await response.drain<void>();
      if (mounted) setState(() => connected = true);
    } catch (_) {
      if (mounted) setState(() => connected = false);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = connected == true;
    final color = connected == null
        ? AppColors.muted
        : isConnected
            ? AppColors.success
            : AppColors.danger;
    final text = connected == null
        ? 'Checking backend'
        : isConnected
            ? 'Backend connected'
            : 'Backend not connected';

    return Tooltip(
      message: '$text\n${AppEnv.apiBaseUrl}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: check,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 7),
                Text(
                  isConnected ? 'Connected' : connected == null ? 'Checking' : 'Offline',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
