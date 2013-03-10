#!/usr/bin/env dart

// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library doc_code_verify;

import 'dart:io';
import 'package:doc_code_verify/doc_code_verifier.dart';

/// Basically, create a DocCodeVerifier object and call its main method.
void main() {
  var verifier = new DocCodeVerifier();
  verifier.main(new Options().arguments);
  exit(verifier.errorsEncountered ? 1 : 0);
}