import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/pdf_export_data.dart';
import '../../services/pdf_export_service.dart';

class PdfExportScreen extends StatelessWidget {
  final PdfExportData data;

  const PdfExportScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final service = PdfExportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xuất PDF'),
        backgroundColor: const Color(0xFFFFF9F3),
        foregroundColor: const Color(0xFF594A50),
      ),
      body: PdfPreview(
        build: (format) => service.generate(data),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '${_safeFileName(data.name)}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không thể tạo PDF:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  String _safeFileName(String name) {
    final result = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    return result.isEmpty ? 'crochet_chart' : result;
  }
}
