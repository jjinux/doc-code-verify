// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:doc_code_verify/doc_code_verifier.dart';

Directory get scriptDir => new File(new Options().script).directorySync();
Directory get projectDir => new Directory(new Path(scriptDir.path).append("..").canonicalize().toNativePath());
Directory get sourceDir => new Directory(new Path(scriptDir.path).append("/sourceDir").canonicalize().toNativePath());
Directory get documentationDir => new Directory(new Path(scriptDir.path).append("/documentationDir").canonicalize().toNativePath());

/**
 * Call a callback with a temporary directory.
 *
 * Delete it once the callback is done.
 */
void callWithTemporaryDirectorySync(void callback(Directory temp)) {
  Directory temp = new Directory("").createTempSync();
  try {
    callback(temp);
  } finally {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  }
}

void main() {
  group('DocCodeVerifier', () {
    DocCodeVerifier verifier;

    setUp(() {
      verifier = new DocCodeVerifier();
    });

    test("scriptName should be doc_code_verify.dart", () {
      expect(verifier.scriptName, equals("doc_code_verify.dart"));
    });

    test("projectDir should have a bin directory in it", () {
      expect(new Directory(new Path(projectDir.path).append("bin").toNativePath()).existsSync(),
             isTrue);
    });

    test('the syntax for example names is pretty permissive', () {
      expect(DocCodeVerifier.beginRegExp.firstMatch("BEGIN(a b/c)"), isNotNull);
      expect(DocCodeVerifier.verifyBlockRegExp.firstMatch("VERIFY(a b/c)"), isNotNull);
      expect(DocCodeVerifier.endRegExp.firstMatch("END(a b/c)"), isNotNull);
    });

    test('correctly matches inline verifys', () {
      expect(DocCodeVerifier.inlineVerifyRegExp.firstMatch("(VERIFY(example))"), isNotNull);
    });

    test('examples is empty by default', () {
      expect(verifier.examples.isEmpty, isTrue);
    });

    test('scanForExamples updates examples', () {
      verifier.scanForExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);

      expect(verifier.examples["add"].join(), equalsIgnoringWhitespace("""
        num add(num a, num b) {
          return a + b;
        }
      """));
    });

    test('scanForExamples permits overlapping examples', () {
      verifier.scanForExamples("""
        // BEGIN(two_lines)
        line
        // BEGIN(one_line)
        line
        // END(two_lines)
        // END(one_line)
        line
        line
      """);

      expect(verifier.examples["one_line"].join(), equalsIgnoringWhitespace("""
        line
      """));

      expect(verifier.examples["two_lines"].join(), equalsIgnoringWhitespace("""
        line
        line
      """));
    });

    test('scanForExamples does not concatenate examples with the same name', () {
      var printedError = false;
      
      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: Warning, the name 'example' was already used"));
        printedError = true;
      }
        
      verifier.scanForExamples("""
        // BEGIN(example)
        line
        // END(example)
        line
        line
        // BEGIN(example)
        line
        // END(example)
      """, print: _print);

      expect(verifier.examples["example"].join(), equalsIgnoringWhitespace("""
        line
      """));
      
      expect(verifier.errorsEncountered, isTrue);
    });
    
    test("scanForExamples complains if you misspell the name of an END", () {
      var printedError = false;

      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: BEGIN for `wrongName` not found; spelling error?"));
        printedError = true;
      }

      // I have to break up BEGIN and END so that they are treated literally
      // in this test, but nowhere else.
      verifier.scanForExamples("""
        // BEGI""" """N(someName)
        line
        // EN""" """D(wrongName)
      """, print: _print);
      
      expect(verifier.errorsEncountered, isTrue);
      expect(printedError, isTrue);
      expect(verifier.examples["someName"].join(),
             equalsIgnoringWhitespace("line"));
    });
    
    test("verifyExamples complains if not in source", () {
      var printedError = false;

      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: 'someName' not found in code directory."));
        printedError = true;
      }

      verifier.verifyExamples("""
        // BEGIN(someName)
        line
        // END(someName)
      """, print: _print);
      
      expect(verifier.errorsEncountered, isTrue);
      expect(printedError, isTrue);
    });
    
    test('verifyExamples returns with no errors', () {
      verifier.scanForExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);
      
      verifier.verifyExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);
      
      expect(verifier.errorsEncountered, equals(false));
    });
    
    test('verifyExamples accepts when whitespace is not the same', () {
      verifier.scanForExamples("""
        // BEGIN(add)
        num    add(num   a, num   b)   {

          return    a    +   b;

        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);
      
      verifier.verifyExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);

      expect(verifier.examples["add"].join(), equalsIgnoringWhitespace("""
        num add(num a, num b) {
          return a + b;
        }
      """));
      
      expect(verifier.errorsEncountered, equals(false));
    });
    
    test('verifyExamples complains if source does not match', () {
      var printedError = false;

      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: 'add' in documentation did not match 'add' in the source code\n\t'add' in the documentation looks like:\n\t        num add(num a, num b) {\n\t          return a * b;\n\t        } \n\n\t'add' in the source looks like:\n\t        num add(num a, num b) {\n\t          return a + b;\n\t        }") );
        printedError = true;
      }
      
      verifier.scanForExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """);
      
      verifier.verifyExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a * b;
        }
        // END(add)

        void main() {
          print("Hello, World!");
        }
      """, print: _print);

      expect(verifier.examples["add"].join(), equalsIgnoringWhitespace("""
        num add(num a, num b) {
          return a + b;
        }
      """));
      
      expect(verifier.errorsEncountered, equals(true));
    });

    test('scanDirectoryForExamples can scan this directory for examples', () {
      // BEGIN(thisTestIsSoMeta)
      // meta meta meta
      // END(thisTestIsSoMeta)
            
      verifier.scanDirectory(projectDir, verifier.scanForExamples);
      expect(verifier.examples.length, greaterThan(1));
      expect(verifier.examples["thisTestIsSoMeta"].join(), equalsIgnoringWhitespace("""
        // meta meta meta
      """));
    });
    
    // Because of the way pub uses symlinks, it's common to see the same file
    // multiple times. Ignore files we've already seen.
    test('scanDirectory should ignore files it has already seen because of symlinks', () {
      verifier.scanDirectory(projectDir, verifier.scanForExamples);
      expect(verifier.examples["symlinkExample"].join(),
             equalsIgnoringWhitespace("// 1"));
    });

    test("parseArguments accepts exactly 2 positional arguments", () {
      String thisDir = scriptDir.path;
      verifier.parseArguments([thisDir, thisDir]);
      expect(verifier.errorsEncountered, isFalse);
      expect(verifier.documentationDirectory.path, equals(thisDir));
    });

    test("parseArguments complains if there aren't exactly 2 positional arguments", () {
      var printedError = false;

      void _print(String s) {
        expect(s, stringContainsInOrder(["doc_code_verify.dart: Expected 2 positional arguments",
                                         "usage: doc_code_verify.dart"]));
        printedError = true;
      }

      verifier.parseArguments([], print: _print);
      expect(verifier.errorsEncountered, isTrue);
      expect(printedError, isTrue);
    });

    test("resolveDirectoryOrExit should return an absolute path", () {
      Directory resolvedDirectory = verifier.resolveDirectoryOrExit('.');
      expect(new Path(resolvedDirectory.path).isAbsolute, isTrue);
    });

    test("resolveDirectoryOrExit should check that a directory exists or exit with an error", () {
      var printedError;
      var exited;

      void _print(String s) {
        expect(s, stringContainsInOrder(["doc_code_verify.dart",
                                         "FileIOException: Cannot retrieve full path for file 'this_should_not_exist'"]));
        printedError = true;
      }

      void _exit(int status) {
        expect(status, 1);
        exited = true;
        throw new Exit();
      }

      expect(() => verifier.resolveDirectoryOrExit('this_should_not_exist', print: _print, exit: _exit),
          throwsA(new isInstanceOf<Exit>()));
      expect(printedError, isTrue);
      expect(exited, isTrue);
    });

    test("main should print usage and exit with status of 0 when you call it with --help", () {
      var printedUsage;
      var exited;

      void _print(String s) {
        expect(s, stringContainsInOrder(["usage: doc_code_verify.dart",
                                         "DOCUMENTATION CODE OUTPUT"]));
        printedUsage = true;
      }

      void _exit(int status) {
        expect(status, 0);
        exited = true;
        throw new Exit();
      }

      ["--help", "-h"].forEach((arg) {
        printedUsage = false;
        exited = false;
        expect(() => verifier.main(["--help"], print: _print, exit: _exit),
            throwsA(new isInstanceOf<Exit>()));
        expect(verifier.errorsEncountered, isFalse);
        expect(printedUsage, isTrue);
        expect(exited, isTrue);
      });
    });

    test("parseArguments should resolve directories", () {
      verifier.parseArguments(['.', '.']);
      expect(new Path(verifier.documentationDirectory.path).isAbsolute, isTrue);
      expect(new Path(verifier.codeDirectory.path).isAbsolute, isTrue);
    });

    test("isPrivate should be false for '.'", () {
      expect(verifier.isPrivate(new Path('.')), isFalse);
    });

    test("isPrivate should be true for '..'", () {
      expect(verifier.isPrivate(new Path('..')), isTrue);
    });

    test("isPrivate should be true for '.git'", () {
      expect(verifier.isPrivate(new Path('.git')), isTrue);
    });

    test("isPrivate should be true for 'foo/.git/bar'", () {
      expect(verifier.isPrivate(new Path('foo/.git/bar')), isTrue);
    });

    test("isPrivate should be false for './foo/bar'", () {
      expect(verifier.isPrivate(new Path('./foo/bar')), isFalse);
    });

    // This test is pretty high level.
    test("main does everything", () {
      callWithTemporaryDirectorySync((Directory tempDir) {
        verifier.main(["--delete-first", sourceDir.path, documentationDir.path],
            print: printNothing);
        expect(verifier.errorsEncountered, isFalse);
      });
    });
  });
}