class ImportProgress {
  const ImportProgress({required this.fraction, required this.message})
      : assert(fraction >= 0 && fraction <= 1);

  final double fraction;
  final String message;

  ImportProgress scale(double factor, {String? prefix}) => ImportProgress(
        fraction: (fraction * factor).clamp(0, 1).toDouble(),
        message: prefix == null ? message : '$prefix: $message',
      );
}

typedef ImportProgressCallback = void Function(ImportProgress progress);
