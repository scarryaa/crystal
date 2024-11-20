import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_event_emitter.dart';

class BaseEditor {
  final Buffer buffer;
  final EditorEventEmitter eventEmitter;

  BaseEditor(this.buffer, this.eventEmitter);
}
