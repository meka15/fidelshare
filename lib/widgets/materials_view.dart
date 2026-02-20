import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class MaterialsView extends StatefulWidget {
  final List<StudyMaterial> materials;
  final Student student;
  final Future<void> Function(StudyMaterial material) onAddMaterial;
  final Future<void> Function(String id) onDeleteMaterial;
  final void Function(String id) onDownloadMaterial;

  const MaterialsView({
    super.key,
    required this.materials,
    required this.student,
    required this.onAddMaterial,
    required this.onDeleteMaterial,
    required this.onDownloadMaterial,
  });

  @override
  State<MaterialsView> createState() => _MaterialsViewState();
}

class _MaterialsViewState extends State<MaterialsView> {
  String _activeCategory = 'All';
  String _searchQuery = '';
  bool _isGeneratingSummary = false;
  String _transferStatus = 'idle'; 
  TransferProgress? _progress;

  static const List<String> categories = ['All', 'Notes', 'Assignments', 'Exams', 'Resources'];

  List<StudyMaterial> get _filtered {
    return widget.materials.where((m) {
      final matchesCategory = _activeCategory == 'All' || m.category == _activeCategory;
      // Search by both uploader name and category/summary for better UX
      final query = _searchQuery.toLowerCase();
      final matchesSearch = m.uploaderName.toLowerCase().contains(query) || 
                            (m.summary?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesSearch;
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Refactored Detail View into a Bottom Sheet for better Android Navigation support
  void _showDetails(StudyMaterial material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MaterialDetailSheet(
        material: material,
        student: widget.student,
        onDownload: () {
          Navigator.pop(context);
          _handleDownload(material);
        },
        onDelete: () async {
          final confirm = await _confirmDelete();
          if (confirm == true) {
            await widget.onDeleteMaterial(material.id);
            if (mounted) Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Material?'),
      content: const Text('This will remove the file for everyone in your section.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ),
  );

  Future<void> _handleDownload(StudyMaterial m) async {
    setState(() { _transferStatus = 'downloading'; _progress = null; });
    try {
      final file = await downloadFileChunked(m.url, m.name, (p) => setState(() => _progress = p));
      widget.onDownloadMaterial(m.id);
      await OpenFilex.open(file.path);
    } catch (e) {
      _showError('Download failed');
    } finally {
      setState(() { _transferStatus = 'idle'; _progress = null; });
    }
  }
Future<String?> _pickUploadCategory() async {
    final options = categories.where((c) => c != 'All').toList();
    String selected = _activeCategory == 'All' ? 'Resources' : _activeCategory;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select category'),
          content: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: options
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setDialogState(() {
              selected = value ?? selected;
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpload() async {
    final chosenCategory = await _pickUploadCategory();
    if (chosenCategory == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() {
      _transferStatus = 'uploading';
      _progress = null;
    });

    try {
      final url = await uploadFile(file, (p) => setState(() => _progress = p));
      setState(() => _isGeneratingSummary = true);

      final summary = await GeminiService.summarizeMaterial(
        file.path.split(Platform.pathSeparator).last,
        chosenCategory,
      );

      final newMaterial = StudyMaterial(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        name: widget.student.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        uploaderId: widget.student.studentId,
        uploaderName: widget.student.name,
        isPublic: true,
        downloadCount: 0,
        category: chosenCategory,
        fileSize: formatFileSize(await file.length()),
        summary: summary.isNotEmpty ? summary : null,
        section: widget.student.section,
      );

      await widget.onAddMaterial(newMaterial);
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _transferStatus = 'idle';
          _progress = null;
          _isGeneratingSummary = false;
        });
      }
    }
  }
  // ... (Keep your _handleUpload and _pickUploadCategory logic, they are solid) ...

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Academic Vault', style: TextStyle(fontWeight: FontWeight.bold)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(110),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      _buildCategoryChips(),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _filtered.isEmpty 
                ? const SliverToBoxAdapter(child: Center(child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('No materials found'),
                  )))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildMaterialCard(_filtered[index]),
                      childCount: _filtered.length,
                    ),
                  ),
            ),
          ],
        ),
        if (_isGeneratingSummary || _transferStatus != 'idle') _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: SearchBar(
            hintText: 'Search notes or authors...',
            leading: const Icon(Icons.search),
            onChanged: (v) => setState(() => _searchQuery = v),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _handleUpload,
          icon: const Icon(Icons.upload_file),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((cat) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(cat),
            selected: _activeCategory == cat,
            onSelected: (_) => setState(() => _activeCategory = cat),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMaterialCard(StudyMaterial m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showDetails(m),
        leading: _buildFileIcon(m.category),
        title: Text(m.uploaderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${m.category} • ${m.fileSize}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildFileIcon(String category) {
    IconData icon;
    Color color;
    switch(category) {
      case 'Exams': icon = Icons.quiz; color = Colors.red; break;
      case 'Notes': icon = Icons.description; color = Colors.blue; break;
      case 'Assignments': icon = Icons.assignment; color = Colors.orange; break;
      default: icon = Icons.folder; color = Colors.grey;
    }
    return CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20));
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_isGeneratingSummary ? "Gemini is summarizing..." : "Transferring: ${_progress?.percentage ?? 0}%"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialDetailSheet extends StatelessWidget {
  final StudyMaterial material;
  final Student student;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _MaterialDetailSheet({required this.material, required this.student, required this.onDownload, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.category.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    Text("Uploaded by ${material.uploaderName}", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (material.uploaderId == student.studentId)
                IconButton.filledTonal(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red)),
            ],
          ),
          const Divider(height: 32),
          Text("AI SUMMARY", style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(material.summary ?? "No summary available for this file.", style: const TextStyle(height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download),
              label: Text("Download (${material.fileSize})"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 