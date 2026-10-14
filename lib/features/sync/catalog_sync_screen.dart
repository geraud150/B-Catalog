import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'catalog_sync_service.dart';

class CatalogSyncScreen extends StatefulWidget {
  const CatalogSyncScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<CatalogSyncScreen> createState() => _CatalogSyncScreenState();
}

class _CatalogSyncScreenState extends State<CatalogSyncScreen> {
  late final CatalogSyncService? _service = SupabaseBootstrap.client == null
      ? null
      : CatalogSyncService(
          database: widget.database,
          client: SupabaseBootstrap.client!,
        );

  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _status;
  String? _error;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signIn() async {
    final client = SupabaseBootstrap.client;
    if (client == null || _isSigningIn) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Saisissez l’e-mail et le mot de passe du catalogue.');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _error = null;
    });
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connexion impossible. Vérifiez vos identifiants.');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseBootstrap.client?.auth.signOut();
    if (mounted) setState(() => _status = null);
  }

  Future<void> _synchronize() async {
    final service = _service;
    if (service == null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _status = null;
      _error = null;
    });

    try {
      final report = await service.synchronize();
      if (!mounted) return;
      setState(() {
        if (report.waitingForInitializer) {
          _status =
              'Un autre appareil initialise le catalogue. Réessayez dans quelques instants.';
        } else if (report.conflicts > 0) {
          _status = _reportText(report);
          _error =
              '${report.conflicts} rapprochement(s) ambigu(s) ou modification(s) concurrente(s) : '
              'les fiches locales concernées ont été conservées.';
        } else {
          _status = _reportText(report);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = describeCatalogSyncError(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _reportText(CatalogSyncReport report) =>
      '${report.uploaded} envoyé(s), ${report.downloaded} reçu(s), '
      '${report.deleted} suppression(s), ${report.merged} fusion(s).';

  @override
  Widget build(BuildContext context) {
    final client = SupabaseBootstrap.client;
    final isConnected = client?.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Synchroniser le catalogue')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_service == null)
              const _SyncMessage(
                icon: Icons.cloud_off_outlined,
                text: 'La synchronisation n’est pas configurée sur cette installation.',
                isError: true,
              )
            else if (!isConnected)
              ..._buildSignInForm()
            else
              ..._buildSyncControls(),
            if (_isLoading || _isSigningIn) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            if (_status != null) ...[
              const SizedBox(height: 20),
              _SyncMessage(icon: Icons.check_circle_outline, text: _status!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              _SyncMessage(
                icon: Icons.error_outline,
                text: _error!,
                isError: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSignInForm() => [
    const _SyncMessage(
      icon: Icons.lock_outline,
      text:
          'Connectez cet appareil au compte partagé du catalogue. La connexion ne sera demandée qu’une fois.',
    ),
    const SizedBox(height: 20),
    TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username],
      decoration: const InputDecoration(
        labelText: 'E-mail du catalogue',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _passwordController,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _signIn(),
      decoration: const InputDecoration(
        labelText: 'Mot de passe',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: _isSigningIn ? null : _signIn,
      icon: const Icon(Icons.login),
      label: const Text('Connecter cet appareil'),
    ),
  ];

  List<Widget> _buildSyncControls() => [
    const _SyncMessage(
      icon: Icons.devices_outlined,
      text:
          'Le premier appareil connecté initialise le catalogue. Les suivants rapprochent automatiquement les articles reconnus par identifiant Loyverse, code-barres ou SKU.',
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: _isLoading ? null : _synchronize,
      icon: const Icon(Icons.sync),
      label: const Text('Synchroniser maintenant'),
    ),
    const SizedBox(height: 10),
    TextButton.icon(
      onPressed: _isLoading ? null : _signOut,
      icon: const Icon(Icons.logout),
      label: const Text('Déconnecter cet appareil'),
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _SyncMessage extends StatelessWidget {
  const _SyncMessage({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            color?.withValues(alpha: 0.08) ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
