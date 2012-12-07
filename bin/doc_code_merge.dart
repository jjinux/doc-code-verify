#!/usr/bin/env dart

// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library doc_code_merge;

import 'dart:io';
import 'package:doc_code_merge/console.dart';

/// Basically, create a DocCodeMerger object and call its main method.
void main() {
  var merger = new DocCodeMerger();
  merger.main(new Options().arguments).then((result) {
    exit(merger.errorsEncountered ? 1 : 0);
  });
}