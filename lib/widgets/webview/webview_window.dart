import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/svg.dart';
import 'package:osaka_app/helpers/themes.dart';
import 'package:osaka_app/helpers/icons.dart';

class WebviewWindow {
  void createWindow({
    required int windowId,
    required bool isOpenDialog,
    required bool isNewWindowLoading,
    required bool allowClosePopUp,
    required Function(bool isOpenDialog) setIsOpenDialog,
    required Function(bool isNewWindowLoading) setIsNewWindowLoading,
    required Function(bool allowClosePopUp) setAllowClosePopUp,
    required BuildContext context,
    required BuildContext? dialogContext,
    required String url,
    required InAppWebViewSettings options,
  }) async {
    final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {
      Factory(() => EagerGestureRecognizer())
    };

    UniqueKey key = UniqueKey();
    setIsOpenDialog(true);
    setIsNewWindowLoading(true);
    Future.delayed(
        const Duration(seconds: 3), (() => {setAllowClosePopUp(true)}));

    showModalBottomSheet<void>(
      isDismissible: allowClosePopUp,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10))),
      builder: (BuildContext context) {
        dialogContext = context;
        return StatefulBuilder(builder: (context, setState) {
          return InkWell(
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              allowClosePopUp ? Navigator.of(context).pop() : null;
            },
            child: Container(
              alignment: Alignment.bottomCenter,
              height: fullHeight(context),
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10))),
                height: fullHeight(context) * 0.83,
                width: fullWidth(context),
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  InkWell(
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      allowClosePopUp ? Navigator.of(context).pop() : null;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: perHeight(context, 20)),
                            child: SvgPicture.asset(
                                Theme.of(context).colorScheme.closeIcon,
                                width: 20,
                                height: 20),
                          ),
                        ),
                        SizedBox(
                          height: perHeight(context, 20),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.8,
                              width: MediaQuery.of(context).size.width,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10))),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: perHeight(context, 50),
                                    width: perHeight(context, 50),
                                    child: (isNewWindowLoading == true)
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : const SizedBox(height: 0, width: 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(10.0),
                      ),
                      child: InAppWebView(
                        key: key,
                        initialUrlRequest:
                            URLRequest(url: WebUri.uri(Uri.parse(url))),
                        gestureRecognizers: gestureRecognizers,
                        windowId: windowId,
                        initialSettings: options,
                        onWebViewCreated:
                            (InAppWebViewController controller) {},
                        onCloseWindow: (controller) => {print('close window')},
                        onLoadStart: (windowController, loadUrl) {},
                        onLoadStop: (controller, loadUrl) async {
                          setState(() {
                            isNewWindowLoading = false;
                          });
                        },
                        onReceivedError: (controller, url, code) {
                          Future.delayed(const Duration(milliseconds: 1000),
                              () {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          });

                          print(
                              '---load error----==$code ---${code.description}');
                        },
                        onCreateWindow: (controller, createWindowAction) async {
                          createWindow(
                              windowId: windowId,
                              setIsOpenDialog: setIsOpenDialog,
                              setIsNewWindowLoading: setIsNewWindowLoading,
                              setAllowClosePopUp: setAllowClosePopUp,
                              isOpenDialog: isOpenDialog,
                              isNewWindowLoading: isNewWindowLoading,
                              allowClosePopUp: allowClosePopUp,
                              context: context,
                              dialogContext: dialogContext,
                              url: url,
                              options: options);
                          return true;
                        },
                        onProgressChanged: (controller, progress) {},
                        onConsoleMessage: (controller, message) {
                          print('------console-log: ${message.message}');
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    ).then((value) {
      setIsOpenDialog(false);
    });
  }
}
