/// The selfie taken with a punch (fork satria).
///
/// Replaces the automatic face-presence gate, which waited for an on-device
/// detector that never fired on some phones and offered no button. Here the
/// person takes the photo themselves; it is sent with the punch and kept on
/// the company server with the location, for HR to review. No on-device
/// face detection, so nothing about it goes to a third party.
library;

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_top_bar.dart';

/// Pops with the photo's file path, or null when the person backs out.
class PunchPhotoScreen extends StatefulWidget {
  const PunchPhotoScreen({super.key});

  @override
  State<PunchPhotoScreen> createState() => _PunchPhotoScreenState();
}

enum _Status { initializing, ready, failed }

class _PunchPhotoScreenState extends State<PunchPhotoScreen> {
  CameraController? _controller;
  _Status _status = _Status.initializing;
  String? _photoPath;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = _Status.failed);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = _Status.ready;
      });
    } catch (_) {
      // Permission refused or no usable camera: the same honest answer.
      if (mounted) setState(() => _status = _Status.failed);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (mounted) setState(() => _photoPath = file.path);
    } catch (_) {
      if (mounted) setState(() => _status = _Status.failed);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          AppTopBar(
            title: 'Attendance photo',
            onDark: true,
            onBack: () => context.pop(),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_status) {
      case _Status.initializing:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.surface),
        );
      case _Status.failed:
        return Padding(
          padding: const EdgeInsets.all(AppSpace.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'The camera could not be opened. Allow camera access for '
                'Interflour HR in Settings, then try again.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.surface),
              ),
              const SizedBox(height: AppSpace.x20),
              AppButton(
                label: 'Back',
                tone: AppButtonTone.onDark,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        );
      case _Status.ready:
        final path = _photoPath;
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x20),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: path == null
                        ? CameraPreview(_controller!)
                        : Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x20,
                0,
                AppSpace.x20,
                AppSpace.x20,
              ),
              child: path == null
                  ? AppButton(
                      label: _capturing ? 'Taking photo...' : 'Take photo',
                      tone: AppButtonTone.onDark,
                      onPressed: _capturing ? null : _capture,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Retake',
                            tone: AppButtonTone.outlinedOnDark,
                            onPressed: () => setState(() => _photoPath = null),
                          ),
                        ),
                        const SizedBox(width: AppSpace.x12),
                        Expanded(
                          child: AppButton(
                            label: 'Use photo',
                            onPressed: () => context.pop(path),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
    }
  }
}
