import 'package:flutter/widgets.dart';

Future<void> safeSetState(State state, VoidCallback fn) async {
  if (!state.mounted) return;
  state.setState(fn);
}
