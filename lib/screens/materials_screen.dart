import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/materials_view.dart';

class MaterialsScreen extends StatelessWidget {
  final List<StudyMaterial> materials;
  final Student student;
  final Future<void> Function(StudyMaterial material) onAddMaterial;
  final Future<void> Function(String id) onDeleteMaterial;
  final void Function(String id) onDownloadMaterial;

  const MaterialsScreen({
    super.key,
    required this.materials,
    required this.student,
    required this.onAddMaterial,
    required this.onDeleteMaterial,
    required this.onDownloadMaterial,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materials')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: MaterialsView(
              materials: materials,
              student: student,
              onAddMaterial: onAddMaterial,
              onDeleteMaterial: onDeleteMaterial,
              onDownloadMaterial: onDownloadMaterial,
            ),
          ),
        ],
      ),
    );
  }
}
