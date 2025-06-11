enum Language {
  dart(displayName: 'Dart', fileExtension: '.dart', templateFolder: 'dart');

  final String displayName;
  final String fileExtension;
  final String templateFolder;

  const Language({required this.displayName, required this.fileExtension, required this.templateFolder});
}
