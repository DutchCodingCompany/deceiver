import 'package:deceiver/deceiver.dart';
import 'package:deceiver_flutter/deceiver_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:material_ui/material_ui.dart';

final deceiver = Deceiver()
  ..on.get(
    '/users',
    jsonResponse(
      body: [
        {'name': 'Bilbo'},
        {'name': 'Frodo'},
      ],
    ),
  )
  ..scenario('empty', (on) => on.get('/users', jsonResponse(body: [])))
  ..scenario(
    'error',
    (on) => on.get('/users', errorResponse(500, message: 'Server error')),
  );

final controller = DeceiverController(deceiver);

// Only use the mocks in debug builds.
final Client httpClient = kDebugMode ? deceiver.client() : Client();

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deceiver example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _result = 'Tap the button to load the users.';

  Future<void> _loadUsers() async {
    try {
      final response = await httpClient.get(
        Uri.parse('https://api.example.com/users'),
      );
      setState(() => _result = '${response.statusCode}: ${response.body}');
    } on ClientException catch (e) {
      setState(() => _result = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deceiver example')),
      // Open the panel with the button in the app bar or by swiping from
      // the right edge.
      endDrawer: kDebugMode
          ? Drawer(
              child: SafeArea(child: DeceiverPanel(controller: controller)),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_result, textAlign: TextAlign.center),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadUsers,
        icon: const Icon(Icons.download),
        label: const Text('GET /users'),
      ),
    );
  }
}
