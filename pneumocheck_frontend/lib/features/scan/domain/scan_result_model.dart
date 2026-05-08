class ScanResultModel {
  final int    scanId;
  final String label;
  final double confidence;
  final String heatmap;

  const ScanResultModel({
    required this.scanId,
    required this.label,
    required this.confidence,
    required this.heatmap,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) => ScanResultModel(
    scanId:     json['scan_id'],
    label:      json['label'],
    confidence: (json['confidence'] as num).toDouble(),
    heatmap:    json['heatmap'],
  );
}