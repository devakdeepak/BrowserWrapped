import 'dart:convert';
import 'dart:io';

/// Thrown when the `browser_wrapped review` subprocess can't be run or
/// its output can't be parsed.
class WrappedServiceException implements Exception {
  WrappedServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Bridges to the Python `browser_wrapped` CLI, which is a separate,
/// independently-runnable tool (see cli.py). Rather than porting the
/// SQLite/history-parsing logic into Dart, we just shell out to it: one
/// `review` call runs `collect` (scan installed browsers, update the
/// local db) and `wrapped` (aggregate stats) back-to-back and prints a
/// single JSON object we can decode here.
class WrappedService {
  WrappedService({this.pythonExecutables = const ['python3', 'python']});

  /// Candidate interpreter names to try, in order. Windows machines often
  /// only have `python` on PATH, while most Linux/macOS setups use
  /// `python3`; we try each until one actually exists.
  final List<String> pythonExecutables;

  /// Runs `python -m browser_wrapped review --json` and returns the
  /// decoded payload: `{"collect_summary": {...}, "wrapped": {...}}`.
  ///
  /// Throws a [WrappedServiceException] if no Python interpreter could be
  /// found, the subprocess exits non-zero, or its stdout isn't valid JSON.
  Future<Map<String, dynamic>> runReview({
    int? year,
    int topN = 10,
    String? dbPath,
  }) async {
    final args = <String>[
      '-m',
      'browser_wrapped',
      'review',
      '--json',
      '--top',
      '$topN',
      if (year != null) ...['--year', '$year'],
      if (dbPath != null) ...['--db', dbPath],
    ];

    ProcessResult? result;
    final attemptErrors = <String>[];

    for (final exe in pythonExecutables) {
      try {
        result = await Process.run(exe, args, runInShell: true);
        break;
      } on ProcessException catch (e) {
        attemptErrors.add('$exe: ${e.message}');
      }
    }

    if (result == null) {
      throw WrappedServiceException(
        'Could not find a Python interpreter to run browser_wrapped '
        '(tried ${pythonExecutables.join(", ")}). ${attemptErrors.join("; ")}',
      );
    }

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw WrappedServiceException(
        'browser_wrapped review failed (exit ${result.exitCode})'
        '${stderr != null && stderr.isNotEmpty ? ": $stderr" : ""}',
      );
    }

    final stdout = (result.stdout as String).trim();
    try {
      return jsonDecode(stdout) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw WrappedServiceException(
        'Could not parse browser_wrapped output as JSON: $e',
      );
    }
  }
}