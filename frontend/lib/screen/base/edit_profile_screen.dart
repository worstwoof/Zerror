import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
import '../../data/file_upload_client.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Color primaryGreen = AppPalette.matchaMist;
  final ImagePicker _picker = ImagePicker();
  final FileUploadClient _fileUploadClient = const FileUploadClient();

  File? _avatarImage;
  bool _initialized = false;
  bool _isSaving = false;

  late final TextEditingController _nameController;
  late final TextEditingController _idController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _idController = TextEditingController();
    _bioController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final store = AppStateScope.of(context);
    _nameController.text = store.userName;
    _idController.text = store.userId;
    _bioController.text = store.userMotto;
    _emailController.text = store.userEmail;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (pickedFile == null) return;
      setState(() => _avatarImage = File(pickedFile.path));
    } catch (error) {
      debugPrint('Pick avatar failed: $error');
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final store = AppStateScope.of(context);

    setState(() => _isSaving = true);
    store.updateProfile(
      name: _nameController.text,
      userId: _idController.text,
      motto: _bioController.text,
      email: _emailController.text,
    );

    if (_avatarImage != null) {
      try {
        final uploaded = await _fileUploadClient.uploadFile(
          filePath: _avatarImage!.path,
          category: 'avatar',
        );
        store.setAvatarPath(uploaded.fileUrl);
      } on FileUploadException catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('资料已更新')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final avatarPath = _avatarImage?.path ?? store.avatarPath;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '编辑资料',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppPalette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: const Text(
              '保存',
              style: TextStyle(
                color: AppPalette.almondCream,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 72),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppPalette.almondCream.withValues(alpha: 0.30),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.honeyOrange.withValues(alpha: 0.12),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.black26,
                            child: _buildAvatarPreview(avatarPath),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppPalette.heroGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppPalette.night, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: AppPalette.night,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const AppSectionTitle(
                  title: '基础资料',
                  subtitle: '更新昵称、账号 ID 和个人简介',
                  icon: Icons.badge_rounded,
                ),
                const SizedBox(height: 16),
                AppPanel(
                  child: Column(
                    children: [
                      _buildInputField(
                        label: '昵称',
                        controller: _nameController,
                        hintText: '请输入昵称',
                      ),
                      const SizedBox(height: 18),
                      _buildInputField(
                        label: '账号 ID',
                        controller: _idController,
                        hintText: '设置专属 ID',
                        helperText: 'ID 会显示在个人主页和侧边栏中',
                      ),
                      const SizedBox(height: 18),
                      _buildInputField(
                        label: '个性签名',
                        controller: _bioController,
                        hintText: '一句话介绍你的学习状态',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const AppSectionTitle(
                  title: '联系信息',
                  subtitle: '后续找回账号和通知会参考这里',
                  icon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 16),
                AppPanel(
                  child: _buildInputField(
                    label: '绑定邮箱',
                    controller: _emailController,
                    hintText: '请输入常用邮箱',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: _isSaving ? '上传中...' : '保存修改',
                    icon: Icons.check_rounded,
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return const Icon(
        Icons.person_rounded,
        color: AppPalette.textPrimary,
        size: 42,
      );
    }

    if (isRemoteMediaPath(avatarPath)) {
      return ClipOval(
        child: Image.network(
          avatarPath,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              color: AppPalette.textPrimary,
              size: 42,
            );
          },
        ),
      );
    }

    return ClipOval(
      child: Image.file(
        File(avatarPath),
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.person_rounded,
            color: AppPalette.textPrimary,
            size: 42,
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppPalette.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppPalette.pastelGrey.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryGreen.withValues(alpha: 0.80),
                width: 1.4,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
