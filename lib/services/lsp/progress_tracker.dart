import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class ProgressTracker {
  final Set<String> _activeProgressTokens = {};
  final ValueNotifier<bool> workProgress = ValueNotifier<bool>(false);
  final ValueNotifier<String> workProgressMessage = ValueNotifier<String>('');
  final _logger = Logger('ProgressTracker');
  Timer? _analysisTimeoutTimer;
  static const analysisTimeout = Duration(seconds: 10);

  void handleProgress(Map<String, dynamic> params) {
    try {
      final token = params['token']?.toString();
      final value = params['value'];

      if (token == null || value == null) {
        _logger.warning('Invalid progress params: $params');
        return;
      }

      final kind = value['kind']?.toString();

      if (kind == null) {
        _logger.warning('Invalid progress kind: $value');
        return;
      }

      switch (kind) {
        case 'begin':
          _beginProgress(token, value);
          break;
        case 'report':
          _reportProgress(token, value);
          break;
        case 'end':
          _endProgress(token);
          break;
        default:
          _logger.warning('Unknown progress kind: $kind');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error handling progress', e, stackTrace);
      clearProgress();
    }
  }

  void _beginProgress(String token, Map<String, dynamic> value) {
    _activeProgressTokens.add(token);
    workProgress.value = true;
    workProgressMessage.value = value['title']?.toString() ?? 'Working...';
    _resetAnalysisTimeout();
  }

  void _reportProgress(String token, Map<String, dynamic> value) {
    if (_activeProgressTokens.contains(token)) {
      workProgressMessage.value =
          value['message']?.toString() ?? workProgressMessage.value;
    }
  }

  void _endProgress(String token) {
    _activeProgressTokens.remove(token);
    if (_activeProgressTokens.isEmpty) {
      clearProgress();
    }
  }

  bool isAnalysisInProgress() {
    return _activeProgressTokens.isNotEmpty || _analysisTimeoutTimer != null;
  }

  void _resetAnalysisTimeout() {
    _analysisTimeoutTimer?.cancel();
    _analysisTimeoutTimer = Timer(analysisTimeout, clearProgress);
  }

  void clearProgress() {
    _analysisTimeoutTimer?.cancel();
    _analysisTimeoutTimer = null;
    _activeProgressTokens.clear();
    workProgress.value = false;
    workProgressMessage.value = '';
  }
}
