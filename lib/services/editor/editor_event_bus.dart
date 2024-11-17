import 'dart:async';

abstract class EditorEvent {
  final DateTime timestamp = DateTime.now();
}

class EditorEventBus {
  static final _controllers = <Type, StreamController>{};

  static void emit<T extends EditorEvent>(T event) {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    (_controllers[T] as StreamController<T>).add(event);
  }

  static Stream<T> on<T extends EditorEvent>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    return (_controllers[T] as StreamController<T>).stream;
  }

  static void dispose() {
    for (var controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
