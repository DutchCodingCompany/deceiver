# deceiver_devtools_extension

The Dart DevTools extension of [deceiver](../deceiver). It is a Flutter web
app that DevTools shows in the "deceiver" tab. It talks to the app via the
`ext.deceiver.*` service extensions in `deceiver/lib/src/devtools.dart`.

This package is not published. Its build is shipped inside `deceiver`, in
`deceiver/extension/devtools/build`. That folder is not in git, so build it
before publishing `deceiver`:

```sh
cd deceiver_devtools_extension
dart run devtools_extensions build_and_copy --source=. --dest=../deceiver/extension/devtools
dart run devtools_extensions validate --package=../deceiver
```

## Developing

Run the extension in the simulated DevTools environment and connect it to an
app that uses `deceiver`, such as `deceiver_flutter/example`:

```sh
flutter run -d chrome --dart-define=use_simulated_environment=true
```

Or build it as above and open DevTools for the running app.
