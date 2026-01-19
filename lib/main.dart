import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import 'rive_parser.dart';
import 'supported_language.dart' show Language, RiveVersion;

void main() {
  runApp(const RiveParserApp());
}

class RiveParserApp extends StatelessWidget {
  const RiveParserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rive ViewModel Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RiveParserHome(),
    );
  }
}

class GeneratedFile {
  final String name;
  final String content;
  final DateTime timestamp;
  final Language language;

  GeneratedFile({
    required this.name,
    required this.content,
    required this.timestamp,
    required this.language,
  });
}

class RiveParserHome extends StatefulWidget {
  const RiveParserHome({super.key});

  @override
  State<RiveParserHome> createState() => _RiveParserHomeState();
}

class _RiveParserHomeState extends State<RiveParserHome> {
  String? _error;
  bool _isProcessing = false;
  bool _isDragging = false;
  final List<GeneratedFile> _generatedFiles = [];
  Timer? _updateTimer;
  Language _selectedLanguage = Language.dart;
  RiveVersion _selectedRiveVersion = RiveVersion.modern;
  bool _useRiveViewModelInterface = false;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveFile(GeneratedFile generatedFile) async {
    if (!kIsWeb) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${generatedFile.language.displayName} File',
        fileName: generatedFile.name,
        type: FileType.custom,
        allowedExtensions: [generatedFile.language.fileExtension],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsString(generatedFile.content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to: $savePath'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Web platform
      final bytes = Uint8List.fromList(generatedFile.content.codeUnits);
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement()
            ..href = url
            ..download = generatedFile.name
            ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File download started'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleFilesDrop(List<DropItemFile> files) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      for (final file in files) {
        if (!file.name.endsWith('.riv')) {
          setState(() {
            _error = 'Skipping non-.riv file: ${file.name}';
          });
          continue;
        }

        final fileNameWithoutExtension = file.name.replaceAll('.riv', '');
        final parser = RiveParser(
          await file.readAsBytes(),
          fileNameWithoutExtension,
        );

        try {
          final generatedCode = await parser.generateCode(
            _selectedLanguage,
            riveVersion: _selectedRiveVersion,
            useInterface: _useRiveViewModelInterface,
          );
          final fileName =
              '${fileNameWithoutExtension}_viewmodel${_selectedLanguage.fileExtension}';

          setState(() {
            _generatedFiles.add(
              GeneratedFile(
                name: fileName,
                content: generatedCode,
                timestamp: DateTime.now(),
                language: _selectedLanguage,
              ),
            );
          });
        } catch (e) {
          setState(() {
            _error = 'Error processing files: $e';
          });
          continue;
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error processing files: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rive ViewModel Generator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Language selection dropdown
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Language',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Language>(
                            initialValue: _selectedLanguage,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items:
                                Language.values.map((language) {
                                  return DropdownMenuItem(
                                    value: language,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getLanguageIcon(language),
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(language.displayName),
                                        const SizedBox(width: 8),
                                        Text(
                                          language.fileExtension,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (Language? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedLanguage = newValue;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Rive version selection dropdown
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rive Package Version',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<RiveVersion>(
                            initialValue: _selectedRiveVersion,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items:
                                RiveVersion.values.map((version) {
                                  return DropdownMenuItem(
                                    value: version,
                                    child: Row(
                                      children: [
                                        Icon(
                                          version == RiveVersion.modern
                                              ? Icons.new_releases
                                              : Icons.history,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(version.displayName),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (RiveVersion? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedRiveVersion = newValue;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Interface options checkbox
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Interface Options',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('Use RiveViewModel Interface'),
                            subtitle: const Text(
                              'Implement common dispose() interface',
                            ),
                            value: _useRiveViewModelInterface,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (bool? value) {
                              setState(() {
                                _useRiveViewModelInterface = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Drop zone
                    Expanded(
                      child: DropTarget(
                        onDragDone: (details) {
                          if (details.files.isNotEmpty) {
                            _handleFilesDrop(
                              details.files.cast<DropItemFile>(),
                            );
                          }
                        },
                        onDragEntered: (details) {
                          setState(() {
                            _isDragging = true;
                          });
                        },
                        onDragExited: (details) {
                          setState(() {
                            _isDragging = false;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  _isDragging
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.file_upload,
                                size: 64,
                                color:
                                    _isDragging
                                        ? Colors.blue
                                        : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isDragging
                                    ? 'Drop to generate code'
                                    : 'Drop .riv files here',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _isDragging ? Colors.blue : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Generated ${_selectedLanguage.displayName} code will be saved as files',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (_isProcessing) ...[
                                const SizedBox(height: 24),
                                const CircularProgressIndicator(),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 24),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Generated Files',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_generatedFiles.isNotEmpty)
                        IconButton(
                          iconSize: 20,
                          onPressed: () {
                            setState(() {
                              _generatedFiles.clear();
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _generatedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _generatedFiles[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _getLanguageIcon(file.language),
                              color: Colors.grey.shade600,
                            ),
                            title: Text(file.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.language.displayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Generated ${_formatTimestamp(file.timestamp)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _saveFile(file),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLanguageIcon(Language language) => switch (language) {
    Language.dart => Icons.flutter_dash,
  };

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
