import 'package:flutter/material.dart';
import 'package:wumble/core/localization/translations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wumble/features/profile/presentation/profile_bloc.dart';
import 'package:wumble/features/profile/domain/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wumble/injection_container.dart';
import 'package:wumble/features/profile/presentation/blocked_users_screen.dart';
import 'package:wumble/core/localization/locale_controller.dart';
import 'package:wumble/core/localization/app_localizations.dart';
import 'package:wumble/core/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  final UserProfile user;
  SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _wallPrivacy;
  late String _chatInvitePrivacy;
  // Notification prefs
  late bool _notifyMessages;
  late bool _notifyLikes;
  late bool _notifyFollowers;
  late bool _notifyMentions;
  // Chat prefs
  late bool _showReadReceipts;
  late bool _showOnlineStatus;
  // Cache
  String _cacheSize = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _wallPrivacy = widget.user.wallPrivacy;
    _chatInvitePrivacy = widget.user.chatInvitePrivacy;
    _notifyMessages = widget.user.notifyMessages;
    _notifyLikes = widget.user.notifyLikes;
    _notifyFollowers = widget.user.notifyFollowers;
    _notifyMentions = widget.user.notifyMentions;
    _showReadReceipts = widget.user.showReadReceipts;
    _showOnlineStatus = widget.user.showOnlineStatus;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final size = await _dirSize(dir);
      if (mounted) {
        setState(() {
          _cacheSize = _formatBytes(size);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = 'No disponible');
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (_) {}
    return totalSize;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearCache() async {
    try {
      // 1. Limpiar archivos temporales (imágenes, etc.)
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: false, followLinks: false)) {
          await entity.delete(recursive: true);
        }
      }

      // 2. Limpiar persistencia local de Firestore
      await FirebaseFirestore.instance.clearPersistence();

      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text(tr('¡Caché y datos locales limpiados!')),
              ],
            ), 
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al limpiar caché: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _updateSetting(String key, dynamic value) {
    sl<ProfileBloc>().add(UpdateSettingsRequested(
      userId: widget.user.id,
      settings: {key: value},
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<ProfileBloc>(),
      child: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Color(0xFF0F0F1A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(tr('Ajustes del Sistema'), style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            padding: EdgeInsets.all(20),
            children: [
              // ──── CUENTA ────
              _buildSectionTitle('Cuenta'),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.email_outlined,
                  title: tr('Cambiar Correo Electrónico'),
                  subtitle: FirebaseAuth.instance.currentUser?.email ?? 'No disponible',
                  onTap: () => _showChangeEmailDialog(context),
                ),
                _buildListTile(
                  icon: Icons.lock_outline_rounded,
                  title: tr('Cambiar Contraseña'),
                  subtitle: 'Actualiza tu seguridad',
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ]),
              const SizedBox(height: 24),

              // ──── IDIOMA ────
              _buildSectionTitle(context.t('language')),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.language,
                  title: context.t('language'),
                  subtitle: LocaleController.displayNames[
                          LocaleController.locale.value.languageCode] ??
                      'Español',
                  onTap: () => _showLanguagePicker(context),
                ),
              ]),
              const SizedBox(height: 24),

              // ──── NOTIFICACIONES ────
              _buildSectionTitle('Notificaciones'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.chat_bubble_outline,
                  title: tr('Mensajes nuevos'),
                  value: _notifyMessages,
                  onChanged: (val) {
                    setState(() => _notifyMessages = val);
                    _updateSetting('notifyMessages', val);
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.favorite_border,
                  title: tr('Likes'),
                  value: _notifyLikes,
                  onChanged: (val) {
                    setState(() => _notifyLikes = val);
                    _updateSetting('notifyLikes', val);
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.person_add_outlined,
                  title: tr('Nuevos seguidores'),
                  value: _notifyFollowers,
                  onChanged: (val) {
                    setState(() => _notifyFollowers = val);
                    _updateSetting('notifyFollowers', val);
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.alternate_email,
                  title: tr('Menciones'),
                  value: _notifyMentions,
                  onChanged: (val) {
                    setState(() => _notifyMentions = val);
                    _updateSetting('notifyMentions', val);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ──── PRIVACIDAD ────
              _buildSectionTitle('Privacidad'),
              _buildSettingsCard([
                _buildPrivacyTile(
                  title: tr('¿Quién puede comentar en mi muro?'),
                  value: _wallPrivacy,
                  onChanged: (val) {
                    setState(() => _wallPrivacy = val!);
                    _updatePrivacy();
                  },
                ),
                _buildDivider(),
                _buildPrivacyTile(
                  title: tr('¿Quién puede invitarme a chats?'),
                  value: _chatInvitePrivacy,
                  onChanged: (val) {
                    setState(() => _chatInvitePrivacy = val!);
                    _updatePrivacy();
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ──── CHAT ────
              _buildSectionTitle('Chat'),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.done_all,
                  title: tr('Confirmación de lectura'),
                  subtitle: 'Mostrar el "visto" en tus mensajes',
                  value: _showReadReceipts,
                  onChanged: (val) {
                    setState(() => _showReadReceipts = val);
                    _updateSetting('showReadReceipts', val);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ──── SEGURIDAD ────
              _buildSectionTitle('Seguridad'),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.shield_outlined,
                  title: tr('Verificación en dos pasos'),
                  subtitle: 'Protege tu cuenta con 2FA',
                  onTap: () => _show2FAInfo(context),
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.devices_rounded,
                  title: tr('Sesiones activas'),
                  subtitle: 'Gestiona tus dispositivos conectados',
                  onTap: () => _showActiveSessionsInfo(context),
                ),
              ]),
              const SizedBox(height: 24),

              // ──── BLOQUEOS ────
              _buildSectionTitle('Bloqueos'),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.block_rounded,
                  title: tr('Usuarios bloqueados'),
                  subtitle: '${widget.user.blockedUserIds.length} usuarios',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BlockedUsersScreen(userId: widget.user.id),
                    ));
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // ──── ALMACENAMIENTO ────
              _buildSectionTitle('Almacenamiento'),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.folder_outlined,
                  title: tr('Espacio en caché'),
                  subtitle: _cacheSize,
                  onTap: () => _showClearCacheDialog(context),
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.cleaning_services_rounded,
                  title: tr('Limpiar caché'),
                  subtitle: 'Libera espacio eliminando datos temporales',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ]),
              const SizedBox(height: 24),

              // ──── ACERCA DE ────
              _buildSectionTitle('Acerca de'),
              _buildSettingsCard([
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                        : 'Cargando...';
                    return _buildListTile(
                      icon: Icons.info_outline,
                      title: tr('Versión de la app'),
                      subtitle: version,
                      onTap: () => _showAppVersionDialog(context, version),
                    );
                  },
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.description_outlined,
                  title: tr('Licencias'),
                  subtitle: 'Licencias de código abierto',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Wumble',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.support_agent_rounded,
                  title: tr('Contacto y soporte'),
                  subtitle: 'Escríbenos para ayuda',
                  onTap: () => _showSupportDialog(context),
                ),
              ]),
              const SizedBox(height: 30),

              // ──── ZONA DE PELIGRO ────
              _buildDangerZone(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _updatePrivacy() {
    sl<ProfileBloc>().add(UpdateProfileRequested(
      userId: widget.user.id,
      wallPrivacy: _wallPrivacy,
      chatInvitePrivacy: _chatInvitePrivacy,
    ));
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(context.t('choose_language'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 8),
              ...LocaleController.supported.map((l) {
                final code = l.languageCode;
                final selected =
                    LocaleController.locale.value.languageCode == code;
                return ListTile(
                  title: Text(
                    LocaleController.displayNames[code] ?? code,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check, color: Wumbleheme.secondaryColor)
                      : null,
                  onTap: () async {
                    await LocaleController.setLocale(code);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
    double iconSize = 20,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white70, size: iconSize),
      ),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildPrivacyTile({required String title, required String value, required ValueChanged<String?> onChanged}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 8),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: Color(0xFF1E1E2C),
            underline: SizedBox(),
            items: [
              DropdownMenuItem(value: 'everyone', child: Text(tr('Todos'), style: const TextStyle(color: Colors.white70))),
              DropdownMenuItem(value: 'members', child: Text(tr('Solo seguidores'), style: TextStyle(color: Colors.white70))),
              DropdownMenuItem(value: 'nobody', child: Text(tr('Nadie'), style: TextStyle(color: Colors.white70))),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 16, endIndent: 16);

  Widget _buildDangerZone() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(tr('Zona de Peligro'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            tr('Una vez que elimines tu cuenta, no podrás recuperar tus datos ni tu progreso.'),
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showDeleteAccountDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('ELIMINAR MI CUENTA'), style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ──── Dialogs ────

  void _showChangeEmailDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('Actualizar Email'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: tr('Nuevo Email'), labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: tr('Contraseña Actual'), labelStyle: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              sl<ProfileBloc>().add(UpdateEmailRequested(newEmail: emailController.text, password: passwordController.text));
              Navigator.pop(context);
            },
            child: Text(tr('VERIFICAR'), style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('Cambiar Contraseña'), style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: tr('Contraseña Actual'), labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: tr('Nueva Contraseña'), labelStyle: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              sl<ProfileBloc>().add(UpdatePasswordRequested(oldPassword: oldPasswordController.text, newPassword: newPasswordController.text));
              Navigator.pop(context);
            },
            child: Text(tr('CAMBIAR'), style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('¿Estás seguro?'), style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Esta acción es irreversible. Por favor ingresa tu contraseña para confirmar.'), style: TextStyle(color: Colors.white70)),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: tr('Contraseña'), labelStyle: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              sl<ProfileBloc>().add(DeleteAccountRequested(password: passwordController.text));
              Navigator.pop(context);
            },
            child: Text(tr('ELIMINAR'), style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Text(tr('Limpiar Caché'), style: TextStyle(color: Colors.white)),
        content: Text(
          'Se eliminarán $_cacheSize de datos temporales. Las imágenes en caché se descargarán de nuevo cuando las necesites.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CANCELAR'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            child: Text(tr('LIMPIAR'), style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _show2FAInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(tr('Verificación en 2 Pasos'), style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'La verificación en dos pasos se gestiona a través de tu proveedor de autenticación (Google, Email).\n\n'
          'Para activar 2FA en tu cuenta de Google, visita myaccount.google.com > Seguridad.\n\n'
          'Para cuentas de email, puedes solicitar un restablecimiento de contraseña periódicamente para mantener tu cuenta segura.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('ENTENDIDO'))),
        ],
      ),
    );
  }

  void _showActiveSessionsInfo(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Row(
          children: [
            Icon(Icons.devices_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(tr('Sesión Activa'), style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sessionInfoRow('Proveedor', user?.providerData.firstOrNull?.providerId ?? 'email'),
            const SizedBox(height: 12),
            _sessionInfoRow('Email', user?.email ?? 'No disponible'),
            const SizedBox(height: 12),
            _sessionInfoRow('Último acceso', user?.metadata.lastSignInTime?.toString().substring(0, 16) ?? 'N/A'),
            const SizedBox(height: 12),
            _sessionInfoRow('Cuenta creada', user?.metadata.creationTime?.toString().substring(0, 16) ?? 'N/A'),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(tr('Cerrar todas las sesiones')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CERRAR'))),
        ],
      ),
    );
  }

  Widget _sessionInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        title: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(tr('Soporte'), style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('¿Necesitas ayuda?'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _supportRow(Icons.email_outlined, 'soporte@wumble.app'),
            SizedBox(height: 8),
            _supportRow(Icons.language, 'wumble.app/soporte'),
            SizedBox(height: 8),
            _supportRow(Icons.discord, 'discord.gg/wumble'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('CERRAR'))),
        ],
      ),
    );
  }

  Widget _supportRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: Colors.white70, fontSize: 14))),
      ],
    );
  }

  void _showAppVersionDialog(BuildContext context, String version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.blueAccent, size: 40),
            ),
            SizedBox(height: 20),
            Text(
              tr('Wumble'),
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              version,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              'Desarrollado con ❤️ para la comunidad.\nEsta versión incluye optimizaciones de caché, iconos adaptativos y visor de imágenes interactivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(tr('GENIAL'), style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
