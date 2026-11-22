import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_password_field.dart';

/// Super Admin only: create administrator accounts, set their passwords and
/// deactivate them. (Admins reset a forgotten password themselves from the
/// login screen's "Forgot Password?" — it emails a link and code.)
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

String _friendly(Object e) => ApiClient.toFriendly(e).toString().replaceFirst('Exception: ', '');

/// Mirrors the backend rule: 8+ characters with letters and numbers.
String? passwordProblem(String p) {
  if (p.length < 8) return 'At least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) return 'Use both letters and numbers.';
  return null;
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().get('/users/admins');
      _admins = [for (final a in (res.data as List? ?? const [])) if (a is Map) Map<String, dynamic>.from(a)];
    } catch (e) {
      final code = e is DioException ? e.response?.statusCode : null;
      _error = code == 403 ? 'Only the Super Admin can manage administrator accounts.' : _friendly(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success));

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CreateAdminSheet(),
    );
    if (created == true) {
      _toast('Admin account created. They can sign in from the Admin login.');
      _load();
    }
  }

  Future<void> _setPassword(Map<String, dynamic> admin) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _SetPasswordDialog(name: admin['name']?.toString() ?? 'this admin'),
    );
    if (password == null) return;
    final id = admin['id'].toString();
    setState(() => _busyId = id);
    try {
      await ApiClient().post('/users/admins/$id/password', data: {'new_password': password});
      _toast('Password updated. ${admin['name']} was signed out of all devices.');
    } catch (e) {
      _toast(_friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _setActive(Map<String, dynamic> admin, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.navy800,
          title: Text('Deactivate ${admin['name']}?'),
          content: const Text('They are signed out immediately and cannot sign in until reactivated.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.fg),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final id = admin['id'].toString();
    setState(() => _busyId = id);
    try {
      await ApiClient().patch('/users/$id', data: {'is_active': active});
      _toast(active ? '${admin['name']} reactivated.' : '${admin['name']} deactivated.');
      await _load();
    } catch (e) {
      _toast(_friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Admin Accounts'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: _error == null
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: AppColors.teal500,
              foregroundColor: AppColors.fg,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add admin'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
              )
            else ...[
              Text(
                'Admins can manage customers, staff and payments. Only you can create, '
                'deactivate or set passwords for admin accounts. An admin who forgets their '
                'password can also reset it from "Forgot Password?" on the Admin login.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
              ),
              const SizedBox(height: 16),
              for (final a in _admins) _adminCard(a),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adminCard(Map<String, dynamic> a) {
    final isSuper = a['is_superadmin'] == true;
    final active = a['is_active'] != false;
    final busy = _busyId == a['id']?.toString();
    return Card(
      color: AppColors.navy800,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: isSuper ? AppColors.gold500.withValues(alpha: 0.6) : AppColors.navy600),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (isSuper ? AppColors.gold500 : AppColors.teal500).withValues(alpha: 0.15),
              child: Icon(isSuper ? Icons.workspace_premium_rounded : Icons.admin_panel_settings_rounded,
                  color: isSuper ? AppColors.gold500 : AppColors.teal500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(a['name']?.toString() ?? 'Admin', style: AppTextStyles.labelLarge)),
                      const SizedBox(width: 8),
                      if (isSuper) _chip('SUPER ADMIN', AppColors.gold500),
                      if (!active) _chip('INACTIVE', AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [a['email'], a['phone']].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!isSuper)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey400),
                onSelected: (v) {
                  if (v == 'password') _setPassword(a);
                  if (v == 'deactivate') _setActive(a, false);
                  if (v == 'activate') _setActive(a, true);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'password', child: Text('Set new password')),
                  if (active)
                    const PopupMenuItem(value: 'deactivate', child: Text('Deactivate'))
                  else
                    const PopupMenuItem(value: 'activate', child: Text('Reactivate')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      );
}

class _CreateAdminSheet extends StatefulWidget {
  const _CreateAdminSheet();

  @override
  State<_CreateAdminSheet> createState() => _CreateAdminSheetState();
}

class _CreateAdminSheetState extends State<_CreateAdminSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    String? problem;
    if (name.length < 2) {
      problem = 'Enter the admin\'s full name.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      problem = 'Enter a valid email (used for password resets).';
    } else if (phone.length != 10) {
      problem = 'Enter a 10-digit mobile number.';
    } else {
      problem = passwordProblem(_password.text);
      if (problem == null && _password.text != _confirm.text) problem = 'Passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient().post('/users/admins',
          data: {'name': name, 'email': email, 'phone': phone, 'password': _password.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _friendly(e);
        });
      }
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New admin account', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text('Share the password with them privately. They can change it after signing in.',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Full name', Icons.person_outline_rounded)),
            const SizedBox(height: 12),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email', Icons.mail_outline_rounded)),
            const SizedBox(height: 12),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _dec('Mobile number', Icons.phone_iphone_rounded)),
            const SizedBox(height: 4),
            SpPasswordField(controller: _password, hint: 'Password (8+ letters & numbers)'),
            const SizedBox(height: 12),
            SpPasswordField(
                controller: _confirm, hint: 'Confirm password', textInputAction: TextInputAction.done),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal500, foregroundColor: AppColors.fg),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetPasswordDialog extends StatefulWidget {
  final String name;
  const _SetPasswordDialog({required this.name});

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.navy800,
      title: Text('New password for ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpPasswordField(controller: _password, hint: 'New password (8+ letters & numbers)'),
          const SizedBox(height: 12),
          SpPasswordField(controller: _confirm, hint: 'Confirm password', textInputAction: TextInputAction.done),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final problem = passwordProblem(_password.text) ??
                (_password.text != _confirm.text ? 'Passwords do not match.' : null);
            if (problem != null) {
              setState(() => _error = problem);
              return;
            }
            Navigator.pop(context, _password.text);
          },
          child: const Text('Set password'),
        ),
      ],
    );
  }
}
