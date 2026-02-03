import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../widgets/loading_dialog_controller.dart';
import '../utils/app_colors_extension.dart';

class LoadingDialog {
  LoadingDialog._shareInstance();
  static final LoadingDialog _shared = LoadingDialog._shareInstance();
  factory LoadingDialog.instance() => _shared;

  LoadingDialogController? _controller;

  void show({required BuildContext context, String text = "Loading", Color? spinColor}) {
    if (_controller?.update(text) ?? false) {
      return;
    } else {
      _controller = showOverlay(context: context, text: text, spinColor: spinColor);
    }
  }

  void hide() {
    _controller?.close();
    _controller = null;
  }

  LoadingDialogController? showOverlay({required BuildContext context, required String text, Color? spinColor}) {
    final textController = StreamController<String>();
    textController.add(text);

    final overlayState = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    bool isTablet = size.width > 500;

    final overlay = OverlayEntry(
      builder: (context) {
        final colors = context.appColors;
        return Material(
          color: Colors.black.withAlpha(150),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: size.width * .8,
                maxHeight: size.width * .8,
                minWidth: size.width * .5,
              ),
              decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(8.r)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    SpinKitCubeGrid(color: spinColor ?? colors.accentOrange, size: isTablet ? 30 : 35),
                    const SizedBox(height: 20),
                    StreamBuilder<String>(
                      stream: textController.stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            snapshot.requireData,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: isTablet ? 12 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(overlay);

    return LoadingDialogController(
      close: () {
        textController.close();
        overlay.remove();
        return true;
      },
      update: (String text) {
        textController.add(text);
        return true;
      },
    );
  }
}
