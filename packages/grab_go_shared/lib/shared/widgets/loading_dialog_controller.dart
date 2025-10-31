// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/foundation.dart' show immutable;

typedef CloseLoadingScreen = bool Function();
typedef UpdateLoadingScreen = bool Function(String text);

@immutable
class LoadingDialogController {
  final CloseLoadingScreen close; // to closs our dialog
  final UpdateLoadingScreen
  update; // to update anytext with in our dialog if needed

  const LoadingDialogController({required this.close, required this.update});
}

