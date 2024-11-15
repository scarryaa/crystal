import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';

class CursorEvent extends EditorEvent {
  final List<Cursor> cursors;
  final int line;
  final int column;
  final bool hasSelection;
  final List<Selection> selections;

  CursorEvent({
    required this.cursors,
    required this.line,
    required this.column,
    required this.hasSelection,
    required this.selections,
  });
}

class ClipboardEvent extends EditorEvent {
  final String text;
  final ClipboardAction action;

  ClipboardEvent({
    required this.text,
    required this.action,
  });
}

enum ClipboardAction { copy, cut, paste }

class FontEvent extends EditorEvent {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;

  FontEvent({
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
  });
}

// Text events
class TextEvent extends EditorEvent {
  final String content;
  final bool isDirty;
  final String? path;

  TextEvent({
    required this.content,
    required this.isDirty,
    this.path,
  });
}

// Selection events
class SelectionEvent extends EditorEvent {
  final List<Selection> selections;
  final bool hasSelection;
  final String selectedText;

  SelectionEvent({
    required this.selections,
    required this.hasSelection,
    required this.selectedText,
  });
}

// File events
class FileEvent extends EditorEvent {
  final String path;
  final String? relativePath;
  final String content;
  final bool isDirty;

  FileEvent({
    required this.path,
    this.relativePath,
    required this.content,
    required this.isDirty,
  });
}

class InsertModeEvent extends EditorEvent {
  final bool isInsertMode;

  InsertModeEvent({
    required this.isInsertMode,
  });
}

// Editor Closing Event
class EditorClosingEvent extends EditorEvent {
  final bool saveStatus;

  EditorClosingEvent({
    required this.saveStatus,
  });
}

// Font Change Event
class FontChangeEvent extends EditorEvent {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;

  FontChangeEvent({
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
  });
}

// Directory Change Event
class DirectoryChangeEvent extends EditorEvent {
  final String path;

  DirectoryChangeEvent({
    required this.path,
  });
}

// Fullscreen Change Event
class FullscreenChangeEvent extends EditorEvent {
  final bool isFullScreen;

  FullscreenChangeEvent({
    required this.isFullScreen,
  });
}

// Layout events
class LayoutEvent extends EditorEvent {
  final LayoutChange type;
  final Map<String, dynamic> data;

  LayoutEvent({
    required this.type,
    required this.data,
  });
}

enum LayoutChange { horizontalSplit, verticalSplit }

// Error events
class ErrorEvent extends EditorEvent {
  final String message;
  final String? path;
  final Object? error;

  ErrorEvent({
    required this.message,
    this.path,
    this.error,
  });
}
