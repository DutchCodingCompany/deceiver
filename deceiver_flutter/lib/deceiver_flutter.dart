/// Flutter debug control panel for the Deceiver HTTP mocking library.
///
/// Provides [DeceiverController] (a reactive [ChangeNotifier] wrapper
/// around [Deceiver]) and [DeceiverPanel] (a Material-styled widget for
/// toggling mocks at runtime).
///
/// ```dart
/// import 'package:deceiver/deceiver.dart';
/// import 'package:deceiver_flutter/deceiver_flutter.dart';
///
/// final deceiver = Deceiver();
/// deceiver.on.get('/users', jsonResponse(body: []));
///
/// final controller = DeceiverController(deceiver);
///
/// // In your widget tree:
/// DeceiverPanel(controller: controller);
/// ```
library;

export 'src/deceiver_controller.dart';
export 'src/deceiver_panel.dart';
