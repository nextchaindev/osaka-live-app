import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashOverlay extends StatelessWidget {
  const SplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/splash_background.png',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x660A1528),
                    Color(0x110A1528),
                    Color(0x330A1528),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오사카를 만나보세요.\n지금, 라이브로.',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF54C3FF),
                        letterSpacing: -0.6,
                        fontFamily: 'SegUI',
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF00BDFE),
                            Color(0xFFFF9500),
                          ],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        '이 순간에 함께하세요.',
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.6,
                          fontFamily: 'SegUI',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '실시간 영상, 진짜 사람들, 실제 장소.\n'
                      '현장의 생생한 정보를 확인하고\n'
                      '더 나은 계획을 세워보세요.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        fontFamily: 'SegUI',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
