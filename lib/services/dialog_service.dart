import 'dart:async';
import 'package:crystal/models/dialog_request.dart';

class DialogService {
  static final DialogService _instance = DialogService._internal();
  factory DialogService() => _instance;
  DialogService._internal();

  final _dialogController = StreamController<DialogRequest>.broadcast();
  final responseController = StreamController<String>.broadcast();

  Stream<DialogRequest> get dialogStream => _dialogController.stream;
  Stream<String> get responseStream => responseController.stream;

  Future<String> showSavePrompt() {
    _dialogController.add(DialogRequest(
        title: 'Unsaved Changes',
        message: 'Would you like to save your changes before exiting?',
        actions: ['Cancel', 'Save & Exit', 'Exit without Saving']));
    return responseController.stream.first;
  }

  Future<String> showMultipleFilesPrompt({
    required String message,
    required List<String> options,
  }) {
    _dialogController.add(DialogRequest(
        title: 'Unsaved Changes', message: message, actions: options));
    return responseController.stream.first;
  }
}
