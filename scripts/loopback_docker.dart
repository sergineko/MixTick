import 'dart:io';

/// Scoped PATH adapter for Supabase CLI 2.120.0's Docker subprocesses.
/// No daemon proxy, firewall/global setting, secrets or argument logging.
List<String> loopbackArguments(List<String> arguments) {
  if (arguments.isEmpty || !{'create', 'run'}.contains(arguments.first)) {
    if (arguments.any(
      (a) => a == '-P' || a.startsWith('-p') || a.startsWith('--publish'),
    )) {
      throw const FormatException(
        'Unsupported container command with port publishing',
      );
    }
    return arguments;
  }
  final result = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (argument == '--network' &&
        i + 1 < arguments.length &&
        arguments[i + 1] == 'host') {
      throw const FormatException('Host networking is forbidden');
    }
    if (argument == '-P' || argument == '--publish-all') {
      throw const FormatException('Implicit port publishing is forbidden');
    }
    if (argument == '-p' || argument == '--publish') {
      if (++i >= arguments.length) {
        throw const FormatException('Missing port binding');
      }
      final binding = arguments[i];
      if (!RegExp(r'^\d+:\d+(/(tcp|udp))?$').hasMatch(binding)) {
        throw const FormatException(
          'Only simple project port bindings allowed',
        );
      }
      result.addAll([argument, '127.0.0.1:$binding']);
    } else if (argument.startsWith('-p') ||
        argument.startsWith('--publish=') ||
        argument.startsWith('--network=host')) {
      throw const FormatException('Unsupported binding syntax');
    } else {
      result.add(argument);
    }
  }
  return result;
}

Future<void> main(List<String> arguments) async {
  const executable = String.fromEnvironment('MIXTICK_REAL_DOCKER');
  if (executable.isEmpty ||
      !File(executable).existsSync() ||
      File(executable).absolute.path ==
          File(Platform.resolvedExecutable).absolute.path) {
    stderr.writeln('Missing real Docker executable');
    exitCode = 2;
    return;
  }
  try {
    final process = await Process.start(
      executable,
      loopbackArguments(arguments),
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } on FormatException {
    stderr.writeln('Refused unsafe local container port configuration');
    exitCode = 2;
  }
}
