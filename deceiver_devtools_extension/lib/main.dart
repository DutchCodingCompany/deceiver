import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/vm_deceiver_service.dart';
import 'src/extension_controller.dart';
import 'src/extension_screen.dart';

void main() {
  runApp(const DevToolsExtension(child: _DeceiverExtension()));
}

/// Below [DevToolsExtension], because `serviceManager` only exists there.
class _DeceiverExtension extends StatefulWidget {
  const _DeceiverExtension();

  @override
  State<_DeceiverExtension> createState() => _DeceiverExtensionState();
}

class _DeceiverExtensionState extends State<_DeceiverExtension> {
  final _service = VmDeceiverService();
  late final _controller = ExtensionController(_service);

  @override
  void dispose() {
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ExtensionScreen(controller: _controller);
}
