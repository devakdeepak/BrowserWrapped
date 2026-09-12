import 'dart:convert';
import 'dart:io';

/// Wraps calls to the Python backend (python -m backend ...) as subprocesses.
/// Assumes the backend package lives at `backendDir` (e.g. .../BrowserWrapped)
/// and is invoked as `python -m backend <command> ...`.
class BrowserWrappedService {
  final String backendDir;   // path to BrowserWrapped/ (parent of backend/)
  final String pythonExe;    // "python3" on mac/linux, "python" on Windows

  BrowserWrappedService({
    required this.backendDir,
    this.pythonExe = 'python3',
  });

  Future<Map<String, dynamic>> _runJsonCommand(List<String> args) async {
    final result = await Process.run(
      pythonExe,
      ['-m', 'backend', ...args],
      workingDirectory: backendDir,
    );

    if (result.exitCode != 0) {
      throw BackendException(
        'Command failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }

    try {
      return jsonDecode(result.stdout as String) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw BackendException('Backend did not return valid JSON: $e\nOutput was: ${result.stdout}');
    }
  }

  /// Runs `collect` (no JSON output for this one — just check exit code).
  Future<void> collect() async {
    final result = await Process.run(
      pythonExe,
      ['-m', 'backend', 'collect'],
      workingDirectory: backendDir,
    );
    if (result.exitCode != 0) {
      throw BackendException('Collect failed: ${result.stderr}');
    }
  }

  /// Runs `wrapped --json [--year YYYY] [--top N]`.
  /// `top` controls how many top domains/pages are returned — pass a
  /// large number (e.g. 9999) if you want effectively "all of them".
  Future<Map<String, dynamic>> getWrapped({int? year, int? top}) {
    return _runJsonCommand([
      'wrapped',
      '--json',
      if (year != null) ...['--year', '$year'],
      if (top != null) ...['--top', '$top'],
    ]);
  }

  /// Runs `personality --json [--year YYYY]`.
  /// Returns { archetype, tagline, description, traits: [...] }
  Future<Map<String, dynamic>> getPersonality({int? year}) {
    return _runJsonCommand([
      'personality',
      '--json',
      if (year != null) ...['--year', '$year'],
    ]);
  }
}

class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => 'BackendException: $message';
}