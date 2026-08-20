// Turns a password into the value a seeded build is compiled with.
//
//   dart run tool/seed_hash.dart
//
// It reads the password from standard input rather than from an argument, so
// it never appears in your shell history, in a process list, or in a file. It
// prints only the hash.
//
// The point of the hash is that the password itself never enters the build.
// Anyone who gets hold of the compiled app — the APK, the web bundle — can
// read whatever is compiled into it, so what is compiled in should not be
// something you could type anywhere else.
//
// Use the output like this, and do not commit it:
//
//   flutter build appbundle --release \
//     --dart-define=PRAYAN_SEED_IDENTIFIER=you@example.com \
//     --dart-define=PRAYAN_SEED_HASH=<the value printed below>
//
// A build with neither define behaves exactly as an unconfigured one: no
// seeded account, sign-up as normal. That is what should go to the stores.

import 'dart:convert';
import 'dart:io';

import 'package:prayan_trading_journal/data/local/local_repositories.dart';

void main() {
  stderr.writeln('Password (input is not echoed back):');
  final echo = stdin.echoMode;
  try {
    stdin.echoMode = false;
  } on Object {
    // Not a terminal — reading from a pipe is fine, there is nothing to hide.
  }

  final password = stdin.readLineSync(encoding: utf8)?.trim() ?? '';

  try {
    stdin.echoMode = echo;
  } on Object {
    // ignore
  }

  if (password.isEmpty) {
    stderr.writeln('No password given.');
    exit(1);
  }
  if (password.length < 8) {
    stderr.writeln('Use at least 8 characters — the app requires it too.');
    exit(1);
  }

  stdout.writeln(LocalAuthRepository.seedHashFor(password));
}
