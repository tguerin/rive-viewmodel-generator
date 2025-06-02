import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import 'parser.dart';

void main() {
  runApp(const RiveParserApp());
}

class RiveParserApp extends StatelessWidget {
  const RiveParserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rive ViewModel Generator',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: const RiveParserHome(),
    );
  }
}

class GeneratedFile {
  final String name;
  final String content;
  final DateTime timestamp;

  GeneratedFile({required this.name, required this.content, required this.timestamp});
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

  @override
  void initState() {
    super.initState();
    // Update timestamps every second
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
        dialogTitle: 'Save Dart File',
        fileName: generatedFile.name,
        type: FileType.custom,
        allowedExtensions: ['dart'],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsString(generatedFile.content);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('File saved to: $savePath'), duration: const Duration(seconds: 2)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File download started'), duration: Duration(seconds: 2)));
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

        final parser = RiveParser(await file.readAsBytes());
        final dartCode = await parser.generateDartCode();

        final fileName = '${file.name.replaceAll('.riv', '')}_viewmodel.dart';

        setState(() {
          _generatedFiles.add(GeneratedFile(name: fileName, content: dartCode, timestamp: DateTime.now()));
        });
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
            flex: 2,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
                padding: const EdgeInsets.all(24),
                child: DropTarget(
                  onDragDone: (details) {
                    if (details.files.isNotEmpty) {
                      _handleFilesDrop(details.files.cast<DropItemFile>());
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
                      border: Border.all(color: _isDragging ? Colors.blue : Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_upload, size: 64, color: _isDragging ? Colors.blue : Colors.grey.shade400),
                        const SizedBox(height: 24),
                        Text(
                          _isDragging ? 'Drop to generate code' : 'Drop .riv files here',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _isDragging ? Colors.blue : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'The generated Dart code will be saved as files',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        if (_isProcessing) ...[const SizedBox(height: 24), const CircularProgressIndicator()],
                        if (_error != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Generated Files', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_generatedFiles.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _generatedFiles.clear();
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear History'),
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
                            title: Text(file.name),
                            subtitle: Text(
                              'Generated ${_formatTimestamp(file.timestamp)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(icon: const Icon(Icons.download), onPressed: () => _saveFile(file)),
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
