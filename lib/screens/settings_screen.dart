import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/api_config.dart';
import '../services/activity_time_service.dart';
import '../services/auth_service.dart';
import '../ui/app_shell.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'auth_screen.dart';
import 'landing_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF185FA5); // strong blue – primary action
const _kPrimaryBg = Color(0xFFE6F1FB); // blue tint – badges / icon bg
const _kPrimaryDk = Color(0xFF0C447C); // dark blue – badge text
const _kSuccess = Color(0xFF0F6E56); // teal – feedback submit
const _kDanger = Color(0xFFA32D2D); // red – logout text/border
const _kDangerBg = Color(0xFFFCEBEB); // red tint – logout bg
const _kStar = Color(0xFFBA7517); // amber – filled star
const _kStarOff = Color(0xFFD3D1C7); // gray – empty star
const _kSurface = Colors.white;
const _kPanelBorder = Color(0x6639D8E8);

// ── Main screen ───────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _age = TextEditingController();
  final _review = TextEditingController();

  String _sex = '';
  int _rating = 0;
  int _savedRating = 0;
  String _savedReview = '';
  bool _loading = true;
  bool _guestMode = false;
  bool _savingProfile = false;
  bool _savingFeedback = false;
  bool _uploadingPhoto = false;
  bool _uploadingCoverPhoto = false;
  String _profileId = '';
  String? _photoUrl;
  String? _coverPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    _contact.dispose();
    _age.dispose();
    _review.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await AuthService().me();
      if (!mounted) return;
      if (profile == null) {
        final cachedProfile = await AuthService.cachedProfile();
        if (!mounted) return;
        if (cachedProfile != null) {
          _applyProfile(cachedProfile);
          await _restoreCachedImages(cachedProfile);
          _showMessage(
              'Profile is offline right now. Your login is still saved.');
          return;
        }
        final hasSession = await AuthService.hasStoredSession();
        if (!hasSession) {
          setState(() => _guestMode = true);
        }
        _showMessage(
            'Profile is offline right now. Your login is still saved.');
        return;
      }
      _applyProfile(profile);
      await _restoreCachedImages(profile);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(UserProfile p) {
    _profileId = p.id;
    _name.text = p.username ?? '';
    _email.text = p.email ?? '';
    _address.text = p.address;
    _contact.text = p.contactNumber;
    _sex = p.sex;
    _age.text = p.age?.toString() ?? '';
    _savedRating = p.appFeedback.rating;
    _savedReview = p.appFeedback.review;
    _photoUrl = _nonEmptyOrExisting(p.photoUrl, _photoUrl);
    _coverPhotoUrl = _nonEmptyOrExisting(p.coverPhotoUrl, _coverPhotoUrl);
    AuthService.cacheProfileImages(
      userId: p.id,
      photoUrl: _photoUrl,
      coverPhotoUrl: _coverPhotoUrl,
    );
  }

  Future<void> _restoreCachedImages(UserProfile p) async {
    if (p.id.trim().isEmpty) return;
    final cachedPhoto = await AuthService.cachedProfilePhoto(p.id);
    final cachedCover = await AuthService.cachedCoverPhoto(p.id);
    if (!mounted) return;
    setState(() {
      _photoUrl = _nonEmptyOrExisting(_photoUrl, cachedPhoto);
      _coverPhotoUrl = _nonEmptyOrExisting(_coverPhotoUrl, cachedCover);
    });
  }

  String? _nonEmptyOrExisting(String? next, String? existing) {
    final value = next?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final previous = existing?.trim() ?? '';
    return previous.isNotEmpty ? previous : null;
  }

  Future<void> _pickAndUploadPhoto() => _pickAndUploadImage(
        uploadingSetter: (v) => _uploadingPhoto = v,
        applyLocalPreview: (value) => _photoUrl = value,
        upload: (picked, bytes) => AuthService().updateProfilePhoto(
          filePath: picked.path,
          bytes: bytes,
          filename: picked.name,
        ),
        successMessage: 'Profile photo updated.',
      );

  Future<void> _pickAndUploadCoverPhoto() => _pickAndUploadImage(
        uploadingSetter: (v) => _uploadingCoverPhoto = v,
        applyLocalPreview: (value) => _coverPhotoUrl = value,
        upload: (picked, bytes) => AuthService().updateCoverPhoto(
          filePath: picked.path,
          bytes: bytes,
          filename: picked.name,
        ),
        successMessage: 'Background photo updated.',
      );

  Future<void> _pickAndUploadImage({
    required void Function(bool) uploadingSetter,
    required void Function(String) applyLocalPreview,
    required Future<UserProfile> Function(XFile, Uint8List) upload,
    required String successMessage,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked == null || !mounted) return;
    setState(() => uploadingSetter(true));
    try {
      final bytes = await picked.readAsBytes();
      final previewValue = _imageDataUri(bytes, picked.mimeType);
      setState(() => applyLocalPreview(previewValue));
      final updated = await upload(picked, bytes);
      if (!mounted) return;
      setState(() => _applyProfile(updated));
      if (_profileId.trim().isNotEmpty) {
        await AuthService.cacheProfileImages(
          userId: _profileId,
          photoUrl: _photoUrl,
          coverPhotoUrl: _coverPhotoUrl,
        );
      }
      _showMessage(successMessage);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => uploadingSetter(false));
    }
  }

  String _imageDataUri(Uint8List bytes, String? mimeType) {
    final mime = (mimeType == null || !mimeType.startsWith('image/'))
        ? 'image/jpeg'
        : mimeType;
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final updated = await AuthService().updateSettings(
        username: _name.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        contactNumber: _contact.text.trim(),
        sex: _sex,
        age: _age.text.trim(),
      );
      if (!mounted) return;
      setState(() => _applyProfile(updated));
      _showMessage('Settings saved.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveFeedback() async {
    if (_savingFeedback) return;
    setState(() => _savingFeedback = true);
    try {
      final sr = _review.text.trim();
      final rt = _rating;
      final updated = await AuthService()
          .updateFeedback(rating: _rating, review: _review.text.trim());
      if (!mounted) return;
      setState(() {
        _applyProfile(updated);
        _savedReview = sr;
        _savedRating = rt;
        _review.clear();
        _rating = 0;
      });
      _showMessage('Feedback saved.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _savingFeedback = false);
    }
  }

  Future<void> _logout() async {
    await ActivityTimeService.instance.prepareForAccountChange();
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()), (_) => false);
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded, color: _kPrimary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 15))),
      ]),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: AppMenuDrawer(
        userName: _name.text.trim().isEmpty ? 'Student' : _name.text.trim(),
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Settings',
      ),
      body: AppBackground(
        imageAsset: 'assets/NEW BACKGROUND/new settings.png',
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : _guestMode
                ? _buildGuestSettings(context)
                : LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    return Column(children: [
                      AppTopBar(
                        onBack: () => Navigator.of(context).pop(),
                        onMenu: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                      ),

                      // ── Title ────────────────────────────────────────────────
                      Transform.translate(
                        offset: const Offset(0, -25),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 0),
                          child: Text(
                            'SETTINGS',
                            style: TextStyle(
                              color: Color(0xFF1500C8),
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(3, 4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Column(children: [
                                _ProfileHero(
                                  photoUrl: _photoUrl,
                                  coverPhotoUrl: _coverPhotoUrl,
                                  displayName: _name.text.trim().isEmpty
                                      ? 'Student'
                                      : _name.text.trim(),
                                  uploading: _uploadingPhoto,
                                  uploadingCover: _uploadingCoverPhoto,
                                  onEditPhoto: _pickAndUploadPhoto,
                                  onEditCover: _pickAndUploadCoverPhoto,
                                ),
                                const SizedBox(height: 14),
                                _SettingsCard(
                                  icon: Icons.badge_outlined,
                                  label: 'Account info',
                                  child: _AccountInfoForm(
                                    email: _email,
                                    address: _address,
                                    contact: _contact,
                                    sex: _sex,
                                    age: _age,
                                    onSexChanged: (v) =>
                                        setState(() => _sex = v),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            Expanded(
                                              child: _SettingsCard(
                                                icon: Icons
                                                    .manage_accounts_outlined,
                                                label: 'Display name',
                                                child: _ProfileDetails(
                                                    name: _name,
                                                    onSave: _saveProfile,
                                                    saving: _savingProfile),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _SettingsCard(
                                                icon:
                                                    Icons.star_outline_rounded,
                                                label: 'Rate this app',
                                                child: _FeedbackPanel(
                                                  userName: _name.text,
                                                  photoUrl: _photoUrl,
                                                  rating: _rating,
                                                  review: _review,
                                                  savedReview: _savedReview,
                                                  savedRating: _savedRating,
                                                  onRatingChanged: (v) =>
                                                      setState(
                                                          () => _rating = v),
                                                  onSave: _saveFeedback,
                                                  saving: _savingFeedback,
                                                ),
                                              ),
                                            ),
                                          ])
                                    : Column(children: [
                                        _SettingsCard(
                                          icon: Icons.manage_accounts_outlined,
                                          label: 'Display name',
                                          child: _ProfileDetails(
                                              name: _name,
                                              onSave: _saveProfile,
                                              saving: _savingProfile),
                                        ),
                                        const SizedBox(height: 12),
                                        _SettingsCard(
                                          icon: Icons.star_outline_rounded,
                                          label: 'Rate this app',
                                          child: _FeedbackPanel(
                                            userName: _name.text,
                                            photoUrl: _photoUrl,
                                            rating: _rating,
                                            review: _review,
                                            savedReview: _savedReview,
                                            savedRating: _savedRating,
                                            onRatingChanged: (v) =>
                                                setState(() => _rating = v),
                                            onSave: _saveFeedback,
                                            saving: _savingFeedback,
                                          ),
                                        ),
                                      ]),
                                const SizedBox(height: 20),
                                _LogoutButton(onTap: _logout),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  }),
      ),
    );
  }

  Widget _buildGuestSettings(BuildContext context) {
    return Column(
      children: [
        AppTopBar(
          onBack: () => Navigator.of(context).pop(),
          onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 10),
          child: Text(
            'SETTINGS',
            style: TextStyle(
              color: Color(0xFF1500C8),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.white,
                  offset: Offset(3, 4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _SettingsCard(
                  icon: Icons.lock_outline_rounded,
                  label: 'Sign in required',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Profile settings are available after you sign in. '
                        'You can go back and keep using the guest lessons.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ActionButton(
                        icon: Icons.login_rounded,
                        label: 'Sign in',
                        color: _kPrimary,
                        onTap: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AuthScreen(initialTab: AuthTab.login),
                          ),
                          (_) => false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Profile hero ──────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final String? photoUrl, coverPhotoUrl;
  final String displayName;
  final bool uploading, uploadingCover;
  final VoidCallback onEditPhoto, onEditCover;

  const _ProfileHero({
    required this.photoUrl,
    required this.coverPhotoUrl,
    required this.displayName,
    required this.uploading,
    required this.uploadingCover,
    required this.onEditPhoto,
    required this.onEditCover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D567E).withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ── Cover ─────────────────────────────────────────────────────────
        Stack(children: [
          SizedBox(
            height: 110,
            width: double.infinity,
            child: coverPhotoUrl != null && coverPhotoUrl!.isNotEmpty
                ? _ProfileImage(
                    value: coverPhotoUrl!,
                    fit: BoxFit.cover,
                    fallback: 'assets/images/PPS.jpg')
                : Image.asset('assets/images/PPS.jpg', fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _UploadChip(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Edit cover',
              uploading: uploadingCover,
              onTap: onEditCover,
            ),
          ),
        ]),
        // ── Avatar + name ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Transform.translate(
              offset: const Offset(0, -20),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kPrimary, width: 3),
                    color: _kPrimaryBg,
                  ),
                  child: ClipOval(
                    child: photoUrl != null && photoUrl!.isNotEmpty
                        ? _ProfileImage(
                            value: photoUrl!,
                            fit: BoxFit.cover,
                            fallback: 'assets/images/app_logo.png',
                          )
                        : const TransparentSignVideoOverlay(
                            videoAsset: 'assets/Set.mp4',
                            fit: BoxFit.cover,
                            volume: 0,
                            threshold: 0.34,
                            smoothing: 0.08,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child:
                      _SmallUploadBtn(uploading: uploading, onTap: onEditPhoto),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kPrimaryBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.hearing_rounded,
                            size: 14, color: _kPrimaryDk),
                        SizedBox(width: 5),
                        Text('Deaf Community Member',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kPrimaryDk)),
                      ]),
                    ),
                  ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _UploadChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool uploading;
  final VoidCallback onTap;
  const _UploadChip(
      {required this.icon,
      required this.label,
      required this.uploading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: uploading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }
}

class _SmallUploadBtn extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;
  const _SmallUploadBtn({required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kPrimary,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: uploading
            ? const Padding(
                padding: EdgeInsets.all(5),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 13),
      ),
    );
  }
}

// ── Settings card shell ───────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _SettingsCard(
      {required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D567E).withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF9FF).withValues(alpha: 0.85),
            border: const Border(
                bottom: BorderSide(color: _kPanelBorder, width: 1)),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _kPrimaryBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 17, color: _kPrimary),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

// ── Field row widget ──────────────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget field;
  const _FieldRow(
      {required this.icon, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.5)),
          ),
          field,
        ])),
      ]),
    );
  }
}

// ── Account info form ─────────────────────────────────────────────────────────
class _AccountInfoForm extends StatelessWidget {
  final TextEditingController email, address, contact, age;
  final String sex;
  final ValueChanged<String> onSexChanged;

  const _AccountInfoForm({
    required this.email,
    required this.address,
    required this.contact,
    required this.sex,
    required this.age,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _FieldRow(
          icon: Icons.alternate_email_rounded,
          label: 'Email',
          field: _StyledTextField(
              controller: email, keyboard: TextInputType.emailAddress)),
      _FieldRow(
          icon: Icons.location_on_outlined,
          label: 'Address',
          field: _StyledTextField(controller: address)),
      _FieldRow(
          icon: Icons.phone_outlined,
          label: 'Contact number',
          field: _StyledTextField(
              controller: contact, keyboard: TextInputType.phone)),
      LayoutBuilder(builder: (ctx, c) {
        final stacked = c.maxWidth < 420;
        final sexDrop = _FieldRow(
          icon: Icons.wc_outlined,
          label: 'Sex',
          field: _StyledDropdown(value: sex, onChanged: onSexChanged),
        );
        final ageFld = _FieldRow(
          icon: Icons.cake_outlined,
          label: 'Age',
          field: _StyledTextField(
              controller: age,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
        );
        if (stacked) return Column(children: [sexDrop, ageFld]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: sexDrop),
          const SizedBox(width: 10),
          Expanded(child: ageFld),
        ]);
      }),
    ]);
  }
}

// ── Profile details ───────────────────────────────────────────────────────────
class _ProfileDetails extends StatelessWidget {
  final TextEditingController name;
  final VoidCallback onSave;
  final bool saving;
  const _ProfileDetails(
      {required this.name, required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FieldRow(
          icon: Icons.badge_outlined,
          label: 'Username',
          field: _StyledTextField(controller: name)),
      const SizedBox(height: 6),
      _ActionButton(
        icon: saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
        label: saving ? 'Saving…' : 'Save profile',
        color: _kPrimary,
        onTap: saving ? null : onSave,
      ),
    ]);
  }
}

// ── Feedback panel ────────────────────────────────────────────────────────────
class _FeedbackPanel extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final int rating;
  final TextEditingController review;
  final String savedReview;
  final int savedRating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSave;
  final bool saving;

  const _FeedbackPanel({
    required this.userName,
    this.photoUrl,
    required this.rating,
    required this.review,
    required this.savedReview,
    required this.savedRating,
    required this.onRatingChanged,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final name = userName.trim().isEmpty ? 'Student' : userName.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // stars
      Semantics(
        label: 'Rating: $rating out of 5 stars',
        child: Row(children: [
          ...List.generate(5, (i) {
            final v = i + 1;
            return GestureDetector(
              onTap: () => onRatingChanged(v),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  v <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: v <= rating ? _kStar : _kStarOff,
                  size: 32,
                ),
              ),
            );
          }),
          if (rating > 0)
            Text('$rating / 5',
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 12),
      // review field
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your review',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        TextField(
          controller: review,
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: _inputDeco('Share your thoughts…'),
        ),
      ]),
      const SizedBox(height: 8),
      _ActionButton(
        icon: saving ? Icons.hourglass_top_rounded : Icons.message_outlined,
        label: saving ? 'Saving…' : 'Submit feedback',
        color: _kSuccess,
        onTap: saving ? null : onSave,
      ),
      // saved preview
      if (savedRating > 0 || savedReview.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EFE8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Previous feedback',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPrimary, width: 2),
                  color: _kPrimaryBg,
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? _ProfileImage(
                          value: photoUrl!,
                          fit: BoxFit.cover,
                          fallback: 'assets/images/app_logo.png')
                      : const Icon(Icons.person_rounded,
                          size: 22, color: _kPrimary),
                ),
              ),
              const SizedBox(width: 10),
              // Name + stars + review
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.black87)),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < savedRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: i < savedRating ? _kStar : _kStarOff,
                                  size: 15)),
                        ),
                      ]),
                      if (savedReview.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(savedReview.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.4)),
                      ],
                    ]),
              ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1.0,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kDangerBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 220,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kDanger, width: 2),
          ),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: _kDanger, size: 22),
            SizedBox(width: 10),
            Text('Log out',
                style: TextStyle(
                    color: _kDanger,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Shared input helpers ──────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  const _StyledTextField(
      {required this.controller, this.keyboard, this.formatters});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: _inputDeco(null),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StyledDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? '' : value,
      isExpanded: true,
      decoration: _inputDeco(null),
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      items: const [
        DropdownMenuItem(value: '', child: Text('Choose')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(
            value: 'Prefer not to say',
            child: Text('Prefer not to say', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

InputDecoration _inputDeco([String? hint]) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF8F8F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kPrimary, width: 2),
      ),
    );

// ── Saved profile image (unchanged logic) ─────────────────────────────────────
class _ProfileImage extends StatelessWidget {
  final String value;
  final BoxFit fit;
  final String fallback;
  const _ProfileImage(
      {required this.value, required this.fit, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUri(value);
    if (bytes != null) {
      return Image.memory(bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => Image.asset(fallback, fit: fit));
    }
    return Image.network(_networkUrl(value),
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(fallback, fit: fit));
  }

  static String _networkUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final baseUrl = ApiConfig.baseUrl;
    if (baseUrl.isEmpty) return value;
    return value.startsWith('/') ? '$baseUrl$value' : '$baseUrl/$value';
  }

  static Uint8List? _decodeDataUri(String v) {
    final ci = v.indexOf(',');
    if (!v.startsWith('data:image/') || ci < 0) return null;
    if (!v.substring(0, ci).toLowerCase().contains(';base64')) return null;
    try {
      return base64Decode(v.substring(ci + 1));
    } on FormatException {
      return null;
    }
  }
}
