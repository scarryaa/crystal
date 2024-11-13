import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class TerminalTab {
  final Terminal terminal;
  final TerminalController controller;
  late final Pty pty;
  final String title;
  final bool isPinned;

  TerminalTab({
    required this.title,
    this.isPinned = false,
  })  : terminal = Terminal(maxLines: 10000),
        controller = TerminalController();
}
