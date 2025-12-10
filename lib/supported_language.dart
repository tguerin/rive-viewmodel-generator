enum Language {
  dart(displayName: 'Dart', fileExtension: '.dart', templateFolder: 'dart');

  final String displayName;
  final String fileExtension;
  final String templateFolder;

  const Language({required this.displayName, required this.fileExtension, required this.templateFolder});
}

enum RiveVersion {
  legacy(displayName: 'Legacy (rive_native)', importStatement: "import 'package:rive_native/rive_native.dart';"),
  modern(displayName: 'Rive 0.14+', importStatement: "import 'package:rive/rive.dart';");

  final String displayName;
  final String importStatement;

  const RiveVersion({required this.displayName, required this.importStatement});
}
