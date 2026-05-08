import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/history_model.dart';

class ScanDetailPage extends StatelessWidget {
  final HistoryModel scan;
  final Uint8List? originalImageBytes;

  const ScanDetailPage({
    super.key,
    required this.scan,
    this.originalImageBytes,
  });

  Uint8List? _effectiveOriginalBytes() {
    if (originalImageBytes != null) {
      return originalImageBytes;
    }

    if (scan.imageB64.isEmpty) {
      return null;
    }

    return base64Decode(scan.imageB64);
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final isPneumonia = scan.label == 'PNEUMONIA';
    final heatmapBytes =
        scan.heatmap.isNotEmpty ? base64Decode(scan.heatmap) : null;
    final originalBytes = _effectiveOriginalBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PneumoCheck',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Rapport minimal de scan',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Text(
                    scan.createdAt.substring(0, 10),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: isPneumonia ? PdfColors.red50 : PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: isPneumonia ? PdfColors.red300 : PdfColors.green300,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      scan.label,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Confiance : ${scan.confidence.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Images du scan',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          'Image initiale',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 150,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: originalBytes != null
                              ? pw.Image(
                                  pw.MemoryImage(originalBytes),
                                  fit: pw.BoxFit.contain,
                                )
                              : pw.Text(
                                  'Image non disponible',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          'Résultat Grad-CAM',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 150,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: heatmapBytes != null
                              ? pw.Image(
                                  pw.MemoryImage(heatmapBytes),
                                  fit: pw.BoxFit.contain,
                                )
                              : pw.Text(
                                  'Carte non disponible',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Légende Grad-CAM',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Rouge / Jaune - Zones très importantes\n'
                      'Vert / Cyan - Zones moyennement importantes\n'
                      'Bleu / Violet - Zones peu importantes',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                'Rapport généré automatiquement par PneumoCheck.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final isPneumonia = scan.label == 'PNEUMONIA';
    final color = isPneumonia ? Colors.red : Colors.green;
    final heatmapBytes =
        scan.heatmap.isNotEmpty ? base64Decode(scan.heatmap) : null;
    final originalBytes = _effectiveOriginalBytes();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'Détail du scan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Générer PDF',
            onPressed: () async {
              final pdfBytes = await _generatePdf();
              await Printing.layoutPdf(
                onLayout: (_) => pdfBytes,
                name: 'PneumoCheck_${scan.createdAt.substring(0, 10)}',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Icon(isPneumonia ? Icons.warning_amber : Icons.check_circle,
                      size: 52, color: color),
                  const SizedBox(height: 8),
                  Text(
                    scan.label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confiance : ${scan.confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: scan.confidence / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date : ${scan.createdAt.substring(0, 10)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (originalBytes != null) ...[
              const Text(
                'Radiographie originale',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    originalBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Carte Grad-CAM - zones analysées',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (heatmapBytes != null)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    heatmapBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              )
            else
              Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text('Carte non disponible'),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Légende Grad-CAM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF185FA5),
                    ),
                  ),
                  SizedBox(height: 8),
                  _LegendRow('Rouge / Jaune', 'Zones très importantes'),
                  _LegendRow('Vert / Cyan', 'Zones moyennement importantes'),
                  _LegendRow('Bleu / Violet', 'Zones peu importantes'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final pdfBytes = await _generatePdf();
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'PneumoCheck_${scan.createdAt.substring(0, 10)}',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'Générer rapport PDF',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final String description;

  const _LegendRow(this.label, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            '→ $description',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
