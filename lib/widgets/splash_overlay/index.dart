import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';

class SplashOverlay extends StatelessWidget {
  const SplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
                    Text(
                      strings.splashHeadline,
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
                      child: Text(
                        strings.splashSubhead,
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
                      strings.splashDescription,
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
