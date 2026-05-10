class ScanResultModel {
  final int scanId;
  final String label;
  final double confidence;
  final String imageB64;
  final String heatmap;
  final String overlay;

  const ScanResultModel({
    required this.scanId,
    required this.label,
    required this.confidence,
    required this.imageB64,
    required this.heatmap,
    required this.overlay,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) =>
      ScanResultModel(
        scanId: json['scan_id'],
        label: json['label'],
        confidence: (json['confidence'] as num).toDouble(),
        imageB64: json['image_b64'] ?? '',
        heatmap: json['heatmap'] ?? '',
        overlay: json['overlay'] ?? json['heatmap'] ?? '',
      );
}
