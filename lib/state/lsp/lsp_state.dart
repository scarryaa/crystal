import 'package:crystal/models/server_command.dart';
import 'package:flutter/material.dart';

class LSPState {
  // Core state notifications
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isInitializing = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusMessage = ValueNotifier<String>('');

  // Server info
  String? currentServerName;
  ServerCommand? currentServerCommand;

  void dispose() {
    isRunning.value = false;
    isInitializing.value = false;
    statusMessage.value = '';
    currentServerName = null;
    currentServerCommand = null;
  }
}
