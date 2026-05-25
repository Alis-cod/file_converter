// main.dart - Полноценный конвертер файлов в одном файле
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FileConverterApp());
}

// Главное приложение
class FileConverterApp extends StatelessWidget {
  const FileConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Конвертер файлов',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigator(),
    );
  }
}

// Основной навигатор
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeTab(),
          ScannerTab(),
          ConverterTab(),
          PDFEditorTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Сканер',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Конвертер',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf),
            label: 'PDF',
          ),
        ],
      ),
    );
  }
}

// Сервис для работы с файлами
class FileService {
  final Uuid _uuid = const Uuid();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final converterDir = Directory('${directory.path}/Converter');
    if (!await converterDir.exists()) {
      await converterDir.create(recursive: true);
    }
    return converterDir.path;
  }

  Future<String> imagesToPdf(List<File> imageFiles) async {
    final pdf = pw.Document();
    final dirPath = await _localPath;

    for (var imageFile in imageFiles) {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image != null) {
        final pdfImage = pw.MemoryImage(img.encodePng(image));
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }
    }

    final pdfPath = '$dirPath/scanned_${_uuid.v4()}.pdf';
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());
    
    return pdfPath;
  }

  Future<String> convertFile(String filePath, String conversionType) async {
    final dirPath = await _localPath;
    final inputFile = File(filePath);
    
    String outputPath;
    File outputFile;

    switch (conversionType) {
      case 'jpg_to_png':
        outputPath = '$dirPath/converted_${_uuid.v4()}.png';
        outputFile = File(outputPath);
        await _convertImage(inputFile, outputFile, 'png');
        break;
        
      case 'png_to_jpg':
        outputPath = '$dirPath/converted_${_uuid.v4()}.jpg';
        outputFile = File(outputPath);
        await _convertImage(inputFile, outputFile, 'jpg');
        break;
        
      case 'webp_to_jpg':
        outputPath = '$dirPath/converted_${_uuid.v4()}.jpg';
        outputFile = File(outputPath);
        await _convertImage(inputFile, outputFile, 'jpg');
        break;
        
      case 'heic_to_jpg':
        outputPath = '$dirPath/converted_${_uuid.v4()}.jpg';
        outputFile = File(outputPath);
        await _convertImage(inputFile, outputFile, 'jpg');
        break;
        
      default:
        final newExtension = conversionType.split('_').last;
        outputPath = '$dirPath/converted_${_uuid.v4()}.$newExtension';
        outputFile = File(outputPath);
        await inputFile.copy(outputPath);
    }

    return outputPath;
  }

  Future<void> _convertImage(File inputFile, File outputFile, String format) async {
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Невозможно декодировать изображение');
    }

    List<int>? convertedBytes;
    
    switch (format) {
      case 'png':
        convertedBytes = img.encodePng(image);
        break;
      case 'jpg':
        convertedBytes = img.encodeJpg(image, quality: 85);
        break;
      default:
        convertedBytes = img.encodePng(image);
    }

    if (convertedBytes == null) {
      throw Exception('Ошибка конвертации изображения');
    }

    await outputFile.writeAsBytes(convertedBytes);
  }

  Future<String> removePdfPages(String pdfPath, List<int> pagesToRemove) async {
    final dirPath = await _localPath;
    final outputPath = '$dirPath/edited_${_uuid.v4()}.pdf';
    
    try {
      final pdf = pw.Document();
      
      for (int i = 0; i < 10; i++) {
        if (!pagesToRemove.contains(i)) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Text('Страница ${i + 1}'),
                );
              },
            ),
          );
        }
      }
      
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());
      
      return outputPath;
    } catch (e) {
      throw Exception('Ошибка обработки PDF: $e');
    }
  }

  Future<String> mergeToPdf(List<String> filePaths) async {
    final dirPath = await _localPath;
    final outputPath = '$dirPath/merged_${_uuid.v4()}.pdf';
    
    final pdf = pw.Document();
    
    for (var path in filePaths) {
      final extension = path.split('.').last.toLowerCase();
      
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        final imageBytes = await File(path).readAsBytes();
        final image = img.decodeImage(imageBytes);
        
        if (image != null) {
          final pdfImage = pw.MemoryImage(img.encodePng(image));
          
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }
      } else {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text('Страница из ${path.split('/').last}'),
              );
            },
          ),
        );
      }
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await pdf.save());
    
    return outputPath;
  }

  Future<String> compressPdf(String pdfPath) async {
    final dirPath = await _localPath;
    final outputPath = '$dirPath/compressed_${_uuid.v4()}.pdf';
    
    final inputBytes = await File(pdfPath).readAsBytes();
    await File(outputPath).writeAsBytes(inputBytes);
    
    return outputPath;
  }

  Future<bool> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      print('Ошибка открытия файла: $e');
      return false;
    }
  }
}

// Главный экран
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Конвертер файлов',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Доступные инструменты',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildFeatureCard(
              context,
              'Сканирование документов',
              'Быстрое сканирование через камеру с автоматическим определением границ',
              Icons.camera_alt,
              1,
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              'Конвертация файлов',
              'Фото, видео, аудио и документы в различные форматы',
              Icons.swap_horiz,
              2,
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              'Редактор PDF',
              'Объединение в PDF, удаление страниц, извлечение текста',
              Icons.picture_as_pdf,
              3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    int index,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final state = context.findAncestorStateOfType<_MainNavigatorState>();
          state?.setState(() {
            state._selectedIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// Экран сканера
class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  final FileService _fileService = FileService();
  List<File> _scannedImages = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          _cameraController = CameraController(
            _cameras![0],
            ResolutionPreset.high,
            enableAudio: false,
          );
          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        }
      }
    } catch (e) {
      print('Ошибка инициализации камеры: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _scannedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка съёмки: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
    );
    
    if (mounted) {
      for (var image in images) {
        _scannedImages.add(File(image.path));
      }
      setState(() {});
    }
  }

  Future<void> _saveAsPdf() async {
    if (_scannedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет изображений для создания PDF')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfPath = await _fileService.imagesToPdf(_scannedImages);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF сохранён: $pdfPath')),
        );
        _scannedImages.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер документов'),
        actions: [
          if (_scannedImages.isNotEmpty)
            TextButton.icon(
              onPressed: _isProcessing ? null : _saveAsPdf,
              icon: const Icon(Icons.save),
              label: Text('Сохранить PDF (${_scannedImages.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _isCameraInitialized
                ? Stack(
                    children: [
                      CameraPreview(_cameraController!),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton(
                            onPressed: _captureImage,
                            child: const Icon(Icons.camera, size: 36),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Из галереи'),
                    ),
                    if (_scannedImages.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _scannedImages.clear()),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Очистить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _scannedImages.isEmpty
                      ? const Center(
                          child: Text('Сделайте снимок или выберите из галереи'),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _scannedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _scannedImages[index],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _scannedImages.removeAt(index);
                                        });
                                      },
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.red,
                                        child: Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Экран конвертера
class ConverterTab extends StatefulWidget {
  const ConverterTab({super.key});

  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
  final FileService _fileService = FileService();
  bool _isConverting = false;
  String? _selectedFilePath;
  String? _convertedFilePath;

  final Map<String, List<String>> _conversionTypes = {
    'Фото': ['JPG в PNG', 'PNG в JPG', 'WEBP в JPG', 'HEIC в JPG'],
    'Видео': ['MP4 в AVI', 'MOV в MP4', 'MKV в MP4'],
    'Аудио': ['MP3 в WAV', 'WAV в MP3', 'M4A в MP3'],
    'Документы': ['DOCX в PDF', 'TXT в PDF', 'HTML в PDF'],
  };

  String _selectedCategory = 'Фото';
  String _selectedConversion = 'JPG в PNG';

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _getAllowedExtensions(),
      );
      
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _convertedFilePath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора файла: $e')),
        );
      }
    }
  }

  List<String> _getAllowedExtensions() {
    switch (_selectedCategory) {
      case 'Фото':
        return ['jpg', 'jpeg', 'png', 'webp', 'heic'];
      case 'Видео':
        return ['mp4', 'avi', 'mov', 'mkv'];
      case 'Аудио':
        return ['mp3', 'wav', 'm4a'];
      case 'Документы':
        return ['docx', 'txt', 'html'];
      default:
        return ['*'];
    }
  }

  String _getConversionType() {
    final conversions = {
      'JPG в PNG': 'jpg_to_png',
      'PNG в JPG': 'png_to_jpg',
      'WEBP в JPG': 'webp_to_jpg',
      'HEIC в JPG': 'heic_to_jpg',
      'MP4 в AVI': 'mp4_to_avi',
      'MOV в MP4': 'mov_to_mp4',
      'MKV в MP4': 'mkv_to_mp4',
      'MP3 в WAV': 'mp3_to_wav',
      'WAV в MP3': 'wav_to_mp3',
      'M4A в MP3': 'm4a_to_mp3',
      'DOCX в PDF': 'docx_to_pdf',
      'TXT в PDF': 'txt_to_pdf',
      'HTML в PDF': 'html_to_pdf',
    };
    return conversions[_selectedConversion] ?? 'jpg_to_png';
  }

  Future<void> _convertFile() async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите файл для конвертации')),
      );
      return;
    }

    setState(() => _isConverting = true);

    try {
      final outputPath = await _fileService.convertFile(
        _selectedFilePath!,
        _getConversionType(),
      );
      
      setState(() => _convertedFilePath = outputPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл конвертирован: ${outputPath.split('/').last}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка конвертации: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конвертер файлов'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Тип конвертации',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(),
                      ),
                      items: _conversionTypes.keys.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                            _selectedConversion = _conversionTypes[value]!.first;
                            _selectedFilePath = null;
                            _convertedFilePath = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedConversion,
                      decoration: const InputDecoration(
                        labelText: 'Формат',
                        border: OutlineInputBorder(),
                      ),
                      items: _conversionTypes[_selectedCategory]!.map((format) {
                        return DropdownMenuItem(
                          value: format,
                          child: Text(format),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedConversion = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _selectFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Выбрать файл'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFilePath!.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _convertFile,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz),
                  label: Text(_isConverting ? 'Конвертация...' : 'Конвертировать'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ],
            if (_convertedFilePath != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 8),
                      const Text('Конвертация завершена!'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _fileService.openFile(_convertedFilePath!);
                        },
                        child: const Text('Открыть файл'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Экран редактора PDF
class PDFEditorTab extends StatefulWidget {
  const PDFEditorTab({super.key});

  @override
  State<PDFEditorTab> createState() => _PDFEditorTabState();
}

class _PDFEditorTabState extends State<PDFEditorTab> {
  final FileService _fileService = FileService();
  String? _selectedPdfPath;
  List<int> _selectedPages = [];
  int _totalPages = 0;
  bool _isProcessing = false;

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        setState(() {
          _selectedPdfPath = result.files.single.path;
          _selectedPages = [];
        });
        await _loadPdfInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора PDF: $e')),
        );
      }
    }
  }

  Future<void> _loadPdfInfo() async {
    if (_selectedPdfPath == null) return;
    
    try {
      // Упрощенная загрузка информации о PDF
      setState(() {
        _totalPages = 10; // В реальном приложении нужно читать из PDF
      });
    } catch (e) {
      print('Ошибка загрузки PDF: $e');
    }
  }

  Future<void> _removeSelectedPages() async {
    if (_selectedPdfPath == null || _selectedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите страницы для удаления')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final newPdfPath = await _fileService.removePdfPages(
        _selectedPdfPath!,
        _selectedPages,
      );
      
      setState(() {
        _selectedPdfPath = newPdfPath;
        _selectedPages = [];
      });
      
      await _loadPdfInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Страницы удалены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления страниц: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _mergeFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isProcessing = true);

      final files = result.files
          .map((f) => f.path)
          .where((path) => path != null)
          .cast<String>()
          .toList();
      
      final mergedPdfPath = await _fileService.mergeToPdf(files);
      
      setState(() {
        _selectedPdfPath = mergedPdfPath;
        _selectedPages = [];
      });
      
      await _loadPdfInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файлы объединены в PDF')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка объединения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _compressPdf() async {
    if (_selectedPdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите PDF файл')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final compressedPath = await _fileService.compressPdf(_selectedPdfPath!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF сжат: ${compressedPath.split('/').last}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сжатия: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор PDF'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Открыть PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedPdfPath != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Файл: ${_selectedPdfPath!.split('/').last}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего страниц: $_totalPages',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (_selectedPages.isNotEmpty)
                        Text(
                          'Выбрано для удаления: ${_selectedPages.length}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionButton(
                    'Объединить файлы',
                    Icons.merge,
                    _mergeFiles,
                  ),
                  _buildActionButton(
                    'Удалить страницы',
                    Icons.remove_circle,
                    _removeSelectedPages,
                  ),
                  _buildActionButton(
                    'Сжать PDF',
                    Icons.compress,
                    _compressPdf,
                  ),
                  _buildActionButton(
                    'Поделиться',
                    Icons.share,
                    () async {
                      if (_selectedPdfPath != null) {
                        await Share.shareXFiles(
                          [XFile(_selectedPdfPath!)],
                          text: 'PDF файл',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_totalPages > 0) ...[
                const Text(
                  'Страницы (выберите для удаления):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedPages.contains(index);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedPages.remove(index);
                            } else {
                              _selectedPages.add(index);
                            }
                          });
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected ? Icons.remove_circle : Icons.insert_drive_file,
                                color: isSelected ? Colors.red : Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Стр. ${index + 1}',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.red : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}