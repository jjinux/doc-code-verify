// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:doc_code_verify/doc_code_verifier.dart';

Directory get scriptDir => new File(new Options().script).directorySync();
Directory get projectDir => new Directory(new Path(scriptDir.path).append("..").canonicalize().toNativePath());

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

    test('scanForExamples concatenates examples with the same name', () {
      verifier.scanForExamples("""
        // BEGIN(example)
        line
        // END(example)
        line
        line
        // BEGIN(example)
        line
        // END(example)
      """);

      expect(verifier.examples["example"].join(), equalsIgnoringWhitespace("""
        line
        line
      """));
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

    test('scanDirectoryForExamples can scan this directory for examples', () {
      // BEGIN(thisTestIsSoMeta)
      // meta meta meta
      // END(thisTestIsSoMeta)
            
      verifier.scanDirectoryForExamples(scriptDir);
      expect(verifier.examples.length, greaterThan(1));
      expect(verifier.examples["thisTestIsSoMeta"].join(), equalsIgnoringWhitespace("""
        // meta meta meta
      """));
    });
    
    // Because of the way pub uses symlinks, it's common to see the same file
    // multiple times. Ignore files we've already seen.
    test('scanDirectoryForExamples should ignore files it has already seen because of symlinks', () {
      verifier.scanDirectoryForExamples(projectDir);
      expect(verifier.examples["symlinkExample"].join(),
             equalsIgnoringWhitespace("// 1"));
    });

    test('verifyExamples verifys in examples', () {
      verifier.scanForExamples("""
        // BEGIN(example)
        Source code
        // END(example)
      """);
      String verifyd = verifier.verifyExamples("""
        Documentation
        VERIFY(example)
        More documentation
      """);
      expect(verifyd, equalsIgnoringWhitespace("""
        Documentation
        Source code
        More documentation
      """));
    });

    test('verifyExamples verifys in inline examples', () {
      verifier.scanForExamples("""
        // BEGIN(small_example)
        <small_example>
        // END(small_example)
      """);
      String verifyd = verifier.verifyExamples("""
        Look at <(VERIFY(small_example))> and <(VERIFY(small_example))>.
      """, filters: [DocCodeVerifier.unindentFilter]);
      expect(verifyd, equalsIgnoringWhitespace("""
        Look at <<small_example>> and <<small_example>>.
      """));
    });

    test('verifyExamples handles multiline inline examples', () {
      verifier.scanForExamples("""
        // BEGIN(multiline_inline)
        if (something) {
          print("Hi");
        }
        // END(multiline_inline)
      """);
      String verifyd = verifier.verifyExamples(
          "<programlisting>(VERIFY(multiline_inline))</programlisting>",
          filters: [DocCodeVerifier.unindentFilter]);

      // I need to be really anal about whitespace for this test.
      expect(verifyd, equals("""<programlisting>if (something) {
  print("Hi");
}</programlisting>\n"""));
    });

    test('verifyExamples applies filters', () {
      verifier.scanForExamples("""
        // BEGIN(example)
        <blink>Hi!</blink>
        // END(example)
      """);
      String verifyd = verifier.verifyExamples("""
        Documentation
        VERIFY(example)
        More documentation
      """, filters: [DocCodeVerifier.htmlEscapeFilter]);
      expect(verifyd, equalsIgnoringWhitespace("""
        Documentation
        &lt;blink&gt;Hi!&lt;/blink&gt;
        More documentation
      """));
    });

    test('verifyExamples handles missing examples', () {
      var printedError = false;

      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: No such example: hello_world"));
        printedError = true;
      }

      String verifyd = verifier.verifyExamples("""
        Documentation
        VERIFY(hello_world)
        More documentation
      """, print: _print);
      expect(verifier.errorsEncountered, isTrue);
      expect(verifyd, equalsIgnoringWhitespace("""
        Documentation
        ERROR: No such example: hello_world
        More documentation
      """));
      expect(printedError, isTrue);

      // BEGIN(hello_world)
      // I'm adding this so that I can run doc_code_verify.dart on itself
      // without encountering errors.
      // END(hello_world)
    });

    test("prepareOutputDirectory should make sure the output directory is not within the documentation or code directories", () {
      callWithTemporaryDirectorySync((tempDir) {
        var printedError = false;
        var exited = false;

        void _print(String s) {
          expect(s, equals("doc_code_verify.dart: The OUTPUT directory must not be within the DOCUMENTATION or CODE directories"));
          printedError = true;
        }
        
        void _exit(int status) {
          expect(status, 1);
          exited = true;
          throw new Exit();
        }
        
        verifier.documentationDirectory = tempDir;
        verifier.codeDirectory = tempDir;
        var outputDirectory = new Directory(new Path(tempDir.path).append("out").canonicalize().toNativePath());

        expect(() => verifier.prepareOutputDirectory(outputDirectory, print: _print, exit: _exit),
            throwsA(new isInstanceOf<Exit>()));
        expect(verifier.errorsEncountered, isTrue);
        expect(printedError, isTrue);
        expect(exited, isTrue);
      });
    });

    test("clearOutputDirectory checks that the output directory doesn't exist", () {
      verifier.clearOutputDirectory(new Directory("this_should_not_exist"));
      expect(verifier.errorsEncountered, isFalse);
    });

    test("clearOutputDirectory complains and exits with error if the directory does exist", () {
      var printedError = false;
      var exited = false;

      void _print(String s) {
        expect(s, equals("doc_code_verify.dart: Could not prepare output directory `${new Directory.current().path}`: Directory already exists\n"
                         "You should either delete it or pass the --delete-first flag"));
        printedError = true;
      }

      void _exit(int status) {
        expect(status, 1);
        exited = true;
        throw new Exit();
      }

      expect(() => verifier.clearOutputDirectory(new Directory.current(), print: _print, exit: _exit),
          throwsA(new isInstanceOf<Exit>()));
      expect(verifier.errorsEncountered, isTrue);
      expect(printedError, isTrue);
      expect(exited, isTrue);
    });

    test("clearOutputDirectory should delete the directory if deleteFirst is true", () {
      callWithTemporaryDirectorySync((tempDir) {
        verifier.deleteFirst = true;
        verifier.clearOutputDirectory(tempDir);
        expect(verifier.errorsEncountered, isFalse);
      });
    });

    test("parseArguments accepts exactly 3 positional arguments", () {
      String thisDir = scriptDir.path;
      verifier.parseArguments([thisDir, thisDir, "OUTPUT"]);
      expect(verifier.errorsEncountered, isFalse);
      expect(verifier.documentationDirectory.path, equals(thisDir));
      expect(verifier.codeDirectory.path, equals(thisDir));
      expect(verifier.outputDirectory.path, equals(new Directory("OUTPUT").path));
    });

    test("parseArguments complains if there aren't exactly 3 positional arguments", () {
      var printedError = false;

      void _print(String s) {
        expect(s, stringContainsInOrder(["doc_code_verify.dart: Expected 3 positional arguments",
                                         "usage: doc_code_verify.dart",
                                         "DOCUMENTATION CODE OUTPUT"]));
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

    test("parseArguments can set the --delete-first flag", () {
      expect(verifier.deleteFirst, isFalse);
      verifier.parseArguments(["--delete-first"], print: printNothing);
      expect(verifier.deleteFirst, isTrue);
    });

    test("parseArguments should resolve directories", () {
      verifier.parseArguments(['.', '.', 'irrelevant']);
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

    test("htmlEscapeFilter escapes HTML", () {
      expect(DocCodeVerifier.htmlEscapeFilter(["<blink>", "hi", "</blink>"]),
             equals(["&lt;blink&gt;", "hi", "&lt;/blink&gt;"]));
    });

    test("indentFilter idents code", () {
      expect(DocCodeVerifier.indentFilter(["Hi", "There"]),
             equals(["\tHi", "\tThere"]));
    });

    test("unindentFilter unindents code", () {
      expect(DocCodeVerifier.unindentFilter(["  1",
                                           "  2"]),
             equals(["1",
                     "2"]));
    });

    test("unindentFilter unindents code where the first line is indented the most", () {
      expect(DocCodeVerifier.unindentFilter(["\t    1",
                                           "\t  2",
                                           "\t    3"]),
             equals(["  1",
                     "2",
                     "  3"]));
    });

    test("unindentFilter does nothing for unindented code", () {
      expect(DocCodeVerifier.unindentFilter(["1",
                                           "2",
                                           "3"]),
             equals(["1",
                     "2",
                     "3"]));
    });

    test("unindentFilter handles empty lists", () {
      expect(DocCodeVerifier.unindentFilter([]),
             equals([]));
    });

    test("unindentFilter does not try to handle inconsistent indentation", () {
      expect(DocCodeVerifier.unindentFilter(["\t1",
                                           "  2",
                                           "    3"
                                           "        4"]),
             equals(["\t1",
                     "  2",
                     "    3"
                     "        4"]));
    });

    test("unindentFilter handles really awkward short lines", () {
      expect(DocCodeVerifier.unindentFilter(["    1",
                                           "2"]),
             equals(["    1",
                     "2"]));
    });

    test("unindentFilter handles blank lines and lines with only indentation", () {
      expect(DocCodeVerifier.unindentFilter(["  1",
                                           "",
                                           " ",
                                           "    2"]),
             equals(["1",
                     "",
                     "",
                     "  2"]));
    });

    test("getFilters should return the right filters for HTML", () {
      List<Filter> filters = verifier.getFilters("index.html");
      List<String> filtered = verifier.applyFilters(filters, ["  a > b;",
                                                            "  c(&d);"]);
      expect(filtered, equals(["a &gt; b;",
                               "c(&amp;d);"]));
    });

    test("getFilters should return the right filters for plain text", () {
      List<Filter> filters = verifier.getFilters("plain.txt");
      List<String> filtered = verifier.applyFilters(filters, ["    >>> Hi",
                                                            "    >>> There!"]);
      expect(filtered, equals(["\t>>> Hi",
                               "\t>>> There!"]));
    });

    // This test is pretty high level.
    test("main does everything", () {
      callWithTemporaryDirectorySync((Directory tempDir) {
        verifier.main(["--delete-first", scriptDir.path, scriptDir.path, tempDir.path],
            print: printNothing);
        expect(verifier.errorsEncountered, isFalse);
      });
    });

    test("ltrim trims the left side of a string", () {
      expect(ltrim(" \tfoo\t "), equals("foo\t "));
    });

    test("rtrim trims the right side of a string", () {
      expect(rtrim(" \tfoo\t "), equals(" \tfoo"));
    });
  });
}