import 'dart:async';

abstract class EditorEvent {
  final DateTime timestamp = DateTime.now();
}

class EditorEventBus {
  static final _instance = StreamController<EditorEvent>.broadcast();

  static Stream<EditorEvent> get stream => _instance.stream;

  static void emit(EditorEvent event) {
    _instance.add(event);
  }

  static void dispose() {
    _instance.close();
  }
}
