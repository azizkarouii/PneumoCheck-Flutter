class HistoryModel {
  final int id;
  final String label;
  final double confidence;
  final String heatmap;
  final String imageB64;
  final String createdAt;

  const HistoryModel({
    required this.id,
    required this.label,
    required this.confidence,
    required this.heatmap,
    required this.imageB64,
    required this.createdAt,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) => HistoryModel(
        id: json['id'],
        label: json['label'],
        confidence: (json['confidence'] as num).toDouble(),
        heatmap: json['heatmap_b64'] ?? '',
        imageB64: json['image_b64'] ?? '',
        createdAt: json['created_at'].toString(),
      );
}
