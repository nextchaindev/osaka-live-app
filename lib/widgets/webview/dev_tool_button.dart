import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/helpers/webview_helper.dart';

class DevToolButton extends StatefulWidget {
  const DevToolButton({super.key});

  @override
  State<DevToolButton> createState() => _DevToolButtonState();
}

class _DevToolButtonState extends State<DevToolButton> {
  Offset? _position;
  bool _showMenu = false;
  PackageInfo? _packageInfo;
  FToast? _fToast;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  void _initFToast(BuildContext context) {
    _fToast ??= FToast();
    _fToast!.init(context);
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = packageInfo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EnvConfig.instance.isDev) return const SizedBox.shrink();
    _initFToast(context);

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    _position ??= Offset(screenW - 70, screenH - 150);

    const double buttonSize = 56.0;
    const double menuWidth = 260.0;
    const double menuHeight = 100.0; // điều chỉnh theo nội dung thực tế

    // Tính vị trí menu sao cho menu nằm phía trên nút và nút chồng lên góc dưới phải menu
    // menuLeft: căn sao cho bên phải menu gần bên phải button, để button chồng lên góc phải
    double menuLeft = _position!.dx - menuWidth + buttonSize;
    // menuTop: để menu 'trên' nút, nhưng một phần vẫn nằm trên (tùy overlap)
    double menuTop = (_position!.dy - menuHeight - buttonSize - 10);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // overlay bắt tap ngoài để đóng menu
        if (_showMenu)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _showMenu = false;
                });
              },
              child: Container(color: Colors.transparent),
            ),
          ),

        // --- BUTTON (vẽ SAU để chồng lên menu) ---
        Positioned(
          left: _position!.dx,
          top: _position!.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // delay nhỏ để tránh race với pointer up
              Future.microtask(() {
                if (!mounted) return;
                setState(() {
                  _showMenu = !_showMenu;
                });
              });
            },
            onPanUpdate: (details) {
              setState(() {
                final newPos = Offset(_position!.dx + details.delta.dx,
                    _position!.dy + details.delta.dy);
                _position = Offset(
                  newPos.dx.clamp(0.0, screenW - buttonSize),
                  newPos.dy.clamp(0.0, screenH - buttonSize),
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade500,
                    Colors.red.shade600,
                    Colors.red.shade700,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade400.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.2,
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.bug_report,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        // --- MENU (vẽ TRƯỚC) ---
        if (_showMenu)
          Positioned(
            left: menuLeft,
            top: menuTop,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: scale,
                    child: child,
                  ),
                );
              },
              child: Material(
                elevation: 16,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // absorb tap bên trong menu (không đóng)
                  },
                  child: Container(
                    width: menuWidth,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.red.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red.shade100.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade200.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMenuRow(
                          icon: Icons.info_outline,
                          label: 'Version',
                          value: _packageInfo != null
                              ? '${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                              : 'Loading...',
                          onTap: null,
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.blue.shade100.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 6),
                        _buildMenuRow(
                          icon: Icons.copy,
                          label: 'Copy FCM Token',
                          value: '',
                          onTap: () async {
                            _initFToast(context);
                            if (_fToast != null) {
                              await WebViewHelper()
                                  .handleCopyFCMToken(_fToast!);
                            }
                            // không đóng menu tự động
                          },
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

  Widget _buildMenuRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade100,
                Colors.red.shade200,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade200.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.red.shade700,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
              if (value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      // dùng InkWell để có ripple; nhưng bao ngoài bằng Material để ripple hiển thị
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // gọi action nhưng KHÔNG tự động đóng menu
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.blue.shade100,
          highlightColor: Colors.blue.shade50,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: row,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: row,
    );
  }
}
