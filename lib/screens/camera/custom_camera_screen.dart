import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:video_player/video_player.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen>
    with WidgetsBindingObserver {
  static const double _captureAspectRatio = 6 / 9;
  static const double _bottomControlsAreaHeight = 214;
  static const Duration _maxRecordingDuration = Duration(seconds: 30);

  List<CameraDescription> _cameras = <CameraDescription>[];
  CameraController? _cameraController;
  CameraDescription? _selectedCamera;
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isFinishingRecording = false;
  bool _isTransferringVideo = false;
  bool _isSubmitted = false;
  XFile? _recordedVideo;
  VideoPlayerController? _recordedVideoController;
  String? _errorMessage;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  final Stopwatch _recordingStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _recordedVideoController?.dispose();
    _cameraController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.pausePreview();
    } else if (state == AppLifecycleState.resumed && !_isRecording) {
      _cameraController?.resumePreview();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final available = await availableCameras();
      if (available.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }

      _cameras = available;
      final backCameraIndex = available.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _selectedCamera = available[backCameraIndex >= 0 ? backCameraIndex : 0];
      await _startController(_selectedCamera!);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to start camera. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final oldController = _cameraController;
    _cameraController = null;
    await oldController?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    setState(() {
      _isInitializing = true;
    });

    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _selectedCamera = camera;
      _isInitializing = false;
      _recordedVideo = null;
      _recordingDuration = Duration.zero;
      _isRecordingPaused = false;
    });
  }

  Future<void> _toggleCamera() async {
    if (_isRecording ||
        _isFinishingRecording ||
        _isTransferringVideo ||
        _selectedCamera == null ||
        !_hasFrontAndBackCameras) {
      return;
    }

    final nextLensDirection =
        _selectedCamera!.lensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
    final nextCamera = _cameraForLensDirection(nextLensDirection);
    if (nextCamera == null) {
      return;
    }

    await _startController(nextCamera);
  }

  bool get _hasFrontAndBackCameras =>
      _cameraForLensDirection(CameraLensDirection.front) != null &&
      _cameraForLensDirection(CameraLensDirection.back) != null;

  CameraDescription? _cameraForLensDirection(
    CameraLensDirection lensDirection,
  ) {
    for (final camera in _cameras) {
      if (camera.lensDirection == lensDirection) {
        return camera;
      }
    }
    return null;
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecording ||
        _isTransferringVideo) {
      return;
    }

    await _recordedVideoController?.dispose();
    _recordedVideoController = null;

    try {
      await controller.resumePreview();
      await controller.startVideoRecording();
      _recordingStopwatch
        ..reset()
        ..start();
      _startRecordingTimer();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _isRecordingPaused = false;
        _recordingDuration = Duration.zero;
        _recordedVideo = null;
        _errorMessage = null;
      });
    } catch (e) {
      _recordingTimer?.cancel();
      _recordingStopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
        _errorMessage = 'Unable to start recording.';
      });
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_isRecording || _isRecordingPaused) {
        return;
      }

      final elapsed = _recordingStopwatch.elapsed;
      if (elapsed >= _maxRecordingDuration) {
        setState(() {
          _recordingDuration = _maxRecordingDuration;
        });
        _finishRecording();
        return;
      }

      setState(() {
        _recordingDuration = elapsed;
      });
    });
  }

  Future<void> _pauseRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        !_isRecording ||
        _isRecordingPaused ||
        _isFinishingRecording) {
      return;
    }

    setState(() {
      _isFinishingRecording = true;
    });

    _recordingTimer?.cancel();

    try {
      await controller.pauseVideoRecording();
      _recordingStopwatch.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingPaused = true;
        _isFinishingRecording = false;
        _recordingDuration = _recordingStopwatch.elapsed > _maxRecordingDuration
            ? _maxRecordingDuration
            : _recordingStopwatch.elapsed;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFinishingRecording = false;
        _errorMessage = 'Unable to pause recording.';
      });
    }
  }

  Future<void> _resumeRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        !_isRecording ||
        !_isRecordingPaused ||
        _isFinishingRecording ||
        _recordingDuration >= _maxRecordingDuration) {
      return;
    }

    setState(() {
      _isFinishingRecording = true;
    });

    try {
      await controller.resumeVideoRecording();
      _recordingStopwatch.start();
      _startRecordingTimer();
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingPaused = false;
        _isFinishingRecording = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFinishingRecording = false;
        _errorMessage = 'Unable to resume recording.';
      });
    }
  }

  Future<XFile?> _finishRecording() async {
    final controller = _cameraController;
    if (controller == null || !_isRecording || _isFinishingRecording) {
      return _recordedVideo;
    }

    setState(() {
      _isFinishingRecording = true;
    });

    _recordingTimer?.cancel();
    _recordingStopwatch.stop();

    try {
      if (_isRecordingPaused) {
        await controller.resumeVideoRecording();
      }
      final file = await controller.stopVideoRecording();
      await controller.pausePreview();
      final videoController = VideoPlayerController.file(File(file.path));
      await videoController.initialize();
      await videoController.setLooping(true);
      if (!mounted) {
        await videoController.dispose();
        return file;
      }

      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
        _isFinishingRecording = false;
        _recordedVideo = file;
        _recordedVideoController = videoController;
        _recordingDuration = _recordingStopwatch.elapsed > _maxRecordingDuration
            ? _maxRecordingDuration
            : _recordingStopwatch.elapsed;
      });
      return file;
    } catch (e) {
      if (!mounted) {
        return null;
      }
      setState(() {
        _isFinishingRecording = false;
        _errorMessage = 'Unable to stop recording.';
      });
      return null;
    }
  }

  Future<void> _handleRecordButtonTap() async {
    if (_isFinishingRecording || _isTransferringVideo) {
      return;
    }

    if (!_isRecording) {
      await _startRecording();
    } else if (_isRecordingPaused) {
      await _resumeRecording();
    } else {
      await _pauseRecording();
    }
  }

  Future<void> _retake() async {
    if (_isTransferringVideo) {
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (_isRecording || controller.value.isRecordingVideo) {
      await _finishRecording();
    }

    await controller.resumePreview();
    await _recordedVideoController?.dispose();
    if (!mounted) {
      return;
    }

    setState(() {
      _recordedVideo = null;
      _recordedVideoController = null;
      _recordingDuration = Duration.zero;
      _isRecording = false;
      _isRecordingPaused = false;
    });
  }

  Future<void> _sendResult({
    required String status,
    String? filePath,
  }) async {
    if (_isSubmitted) {
      return;
    }

    final controller = context.read<WebViewProvider>();
    await controller.sendCameraResult(
      status: status,
      filePath: filePath,
      durationMs: _recordingDuration.inMilliseconds,
      cameraFacing: _selectedCamera?.lensDirection.name,
      mediaType: 'video',
      errorMessage: _errorMessage,
    );
    _isSubmitted = true;
  }

  List<String> _splitBase64(String value, int chunkSize) {
    if (value.isEmpty) {
      return <String>[];
    }

    final chunks = <String>[];
    for (var index = 0; index < value.length; index += chunkSize) {
      final end =
          index + chunkSize < value.length ? index + chunkSize : value.length;
      chunks.add(value.substring(index, end));
    }
    return chunks;
  }

  Future<void> _sendRecordedFileToWeb(
    WebViewProvider webViewProvider,
    XFile file,
  ) async {
    final bytes = await File(file.path).readAsBytes();
    final base64Value = base64Encode(bytes);
    final chunks = _splitBase64(base64Value, 120000);
    final transferId = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = file.path.split('/').last;

    await webViewProvider.sendCameraFileTransfer(
      transferId: transferId,
      fileName: fileName,
      mimeType: 'video/mp4',
      base64Chunks: chunks,
      sizeBytes: bytes.length,
      durationMs: _recordingDuration.inMilliseconds,
      cameraFacing: _selectedCamera?.lensDirection.name,
    );
  }

  Future<void> _confirmRecording() async {
    if (_isTransferringVideo) {
      return;
    }

    final webViewProvider = context.read<WebViewProvider>();
    final file = _recordedVideo ?? await _finishRecording();
    if (file == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isTransferringVideo = true;
        _errorMessage = null;
      });
    }

    try {
      await _sendRecordedFileToWeb(webViewProvider, file);
      await _sendResult(status: 'confirmed', filePath: file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferringVideo = false;
          _errorMessage = 'Unable to send video. Please try again.';
        });
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _closeScreen() async {
    if (_isTransferringVideo) {
      return;
    }

    if (_isRecording) {
      await _finishRecording();
    }

    await _sendResult(status: 'cancelled', filePath: _recordedVideo?.path);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildRecordedVideoPlayer() {
    final controller = _recordedVideoController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: const Color(0xFF2A2A2A),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_isTransferringVideo) {
          return;
        }

        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          AnimatedOpacity(
            opacity: controller.value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_recordedVideo != null) {
      return _buildRecordedVideoPlayer();
    }

    final controller = _cameraController;
    final isReady = controller != null && controller.value.isInitialized;

    if (_isInitializing || !isReady) {
      return Container(
        color: const Color(0xFF2A2A2A),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        final previewAspectRatio = previewSize == null
            ? _captureAspectRatio
            : previewSize.height / previewSize.width;

        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / previewAspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleIconButton(
                icon: Icons.close_rounded,
                onTap: _closeScreen,
                isDisabled: _isTransferringVideo,
              ),
            ),
            const _GpsPill(),
            if (!_isRecording && !_isFinishingRecording)
              Align(
                alignment: Alignment.centerRight,
                child: _CircleIconButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: _toggleCamera,
                  isDisabled: _isTransferringVideo || !_hasFrontAndBackCameras,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_recordedVideo != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '다시 찍기',
                  backgroundColor: const Color(0xFFFFF2F1),
                  foregroundColor: const Color(0xFFFF4C3A),
                  onTap: _retake,
                  isDisabled: _isTransferringVideo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '다음',
                  backgroundColor: const Color(0xFFFF4C3A),
                  foregroundColor: Colors.white,
                  onTap: _confirmRecording,
                  isLoading: _isTransferringVideo,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            _isRecording
                ? _formatDuration(_recordingDuration)
                : '5-30초 라이브 영상만 허용',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: _isRecording ? 20 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RecordButton(
                  isRecording: _isRecording,
                  isPaused: _isRecordingPaused,
                  isBusy: _isFinishingRecording,
                  progress: _recordingDuration.inMilliseconds /
                      _maxRecordingDuration.inMilliseconds,
                  onTap: _handleRecordButtonTap,
                ),
                if (_isRecording)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DoneButton(
                      isDisabled: _isFinishingRecording,
                      onTap: _finishRecording,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            opacity: _isRecording || _recordedVideo != null ? 0 : 1,
            duration: const Duration(milliseconds: 160),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '🔒 갤러리 업로드 불가 · 현장 라이브만',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isTransferringVideo) {
          _closeScreen();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF181818),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _captureAspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreview(),
                            if (_recordedVideo == null)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0x22000000),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            if (_errorMessage != null)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16 + bottomInset,
                                child: _ErrorBanner(message: _errorMessage!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: _bottomControlsAreaHeight +
                    MediaQuery.of(context).padding.bottom,
                child: _buildBottomControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.isPaused,
    required this.isBusy,
    required this.progress,
    required this.onTap,
  });

  final bool isRecording;
  final bool isPaused;
  final bool isBusy;
  final double progress;
  final VoidCallback onTap;

  static const Color _recordRed = Color(0xFFFF3B32);

  @override
  Widget build(BuildContext context) {
    final isIdle = !isRecording;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return InkResponse(
      onTap: isBusy ? null : onTap,
      radius: 46,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: isIdle ? Colors.transparent : const Color(0xFF323232),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isIdle ? Colors.white : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            if (!isIdle)
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: clampedProgress,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  color: _recordRed,
                  strokeCap: StrokeCap.round,
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isIdle ? 62 : 34,
              height: isIdle ? 62 : 34,
              decoration: BoxDecoration(
                color: _recordRed,
                borderRadius: BorderRadius.circular(
                  isIdle || isPaused ? 999 : 9,
                ),
              ),
              child: isPaused
                  ? const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: isDisabled ? null : onTap,
      radius: 28,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.isDisabled,
    required this.onTap,
  });

  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: isDisabled ? null : onTap,
      radius: 28,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.48 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 26,
            color: Color(0xFF181818),
          ),
        ),
      ),
    );
  }
}

class _GpsPill extends StatelessWidget {
  const _GpsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2CC45E),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332CC45E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        '통화 리뷰 · GPS 인증중',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.isDisabled = false,
    this.isLoading = false,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isInactive = isDisabled || isLoading;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.48 : 1,
        duration: const Duration(milliseconds: 160),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isInactive ? null : onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: foregroundColor,
                      ),
                    )
                  : Text(
                      label,
                      key: ValueKey(label),
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
