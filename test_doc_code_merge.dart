// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import('dart:io');
#import('package:unittest/unittest.dart');
#import('doc_code_merge.dart');

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
      temp.deleteRecursivelySync();
    }
  }
}

/// Return this script's directory.
Directory getScriptDirectory() {
  return new File(new Options().script).directorySync();
}

void main() {
  group('DocCodeMerger', () {
    DocCodeMerger merger;
    
    setUp(() {
      merger = new DocCodeMerger();
    });
    
    test('the syntax for example names is pretty permissive', () {
      expect(DocCodeMerger.beginRegExp.firstMatch("BEGIN(a b/c)"), isNotNull);
      expect(DocCodeMerger.mergeRegExp.firstMatch("MERGE(a b/c)"), isNotNull);
      expect(DocCodeMerger.endRegExp.firstMatch("END(a b/c)"), isNotNull);
    });
    
    test('examples is empty by default', () {
      expect(merger.examples.isEmpty(), isTrue);
    });
    
    test('scanForExamples updates examples', () {      
      merger.scanForExamples("""
        // BEGIN(add)
        num add(num a, num b) {
          return a + b;
        }
        // END(add)
        
        void main() {
          print("Hello, World!");
        }
      """);
      
      expect(Strings.concatAll(merger.examples["add"]), equalsIgnoringWhitespace("""
        num add(num a, num b) {
          return a + b;
        }
      """));
    });
    
    test('scanForExamples permits overlapping examples', () {
      merger.scanForExamples("""
        // BEGIN(two_lines)
        line
        // BEGIN(one_line)
        line
        // END(two_lines)
        // END(one_line)
        line
        line
      """);
      
      expect(Strings.concatAll(merger.examples["one_line"]), equalsIgnoringWhitespace("""
        line
      """));

      expect(Strings.concatAll(merger.examples["two_lines"]), equalsIgnoringWhitespace("""
        line
        line
      """));
    });
    
    test('scanForExamples concatenates examples with the same name', () {
      merger.scanForExamples("""
        // BEGIN(example)
        line
        // END(example)
        line
        line
        // BEGIN(example)
        line
        // END(example)
      """);
      
      expect(Strings.concatAll(merger.examples["example"]), equalsIgnoringWhitespace("""
        line
        line
      """));
    });
    
    test('scanDirectoryForExamples can scan this directory for examples', () {
      // BEGIN(thisTestIsSoMeta)
      // meta meta meta
      // END(thisTestIsSoMeta)
      merger.scanDirectoryForExamples(getScriptDirectory()).then(expectAsync1((completed) {
        expect(merger.examples.length, greaterThan(1));
        expect(Strings.concatAll(merger.examples["thisTestIsSoMeta"]), equalsIgnoringWhitespace("""
          // meta meta meta
        """));
      }));
    });

    test('mergeExamples merges in examples', () {
      merger.scanForExamples("""
        // BEGIN(example)
        Source code
        // END(example)
      """); 
      String merged = merger.mergeExamples("""
        Documentation
        MERGE(example)
        More documentation
      """);
      expect(merged, equalsIgnoringWhitespace("""
        Documentation
        Source code
        More documentation
      """));
    });
 
    test('mergeExamples applies filters', () {
      merger.scanForExamples("""
        // BEGIN(example)
        <blink>Hi!</blink>
        // END(example)
      """); 
      String merged = merger.mergeExamples("""
        Documentation
        MERGE(example)
        More documentation
      """, filters: [DocCodeMerger.htmlEscapeFilter]);
      expect(merged, equalsIgnoringWhitespace("""
        Documentation
        &lt;blink&gt;Hi!&lt;/blink&gt;
        More documentation
      """));
    });
    
    test('mergeExamples handles missing examples', () {
      var printedError = false;
      
      void _print(String s) {
        expect(s, equals("$scriptName: No such example: hello_world"));
        printedError = true;
      }

      String merged = merger.mergeExamples("""
        Documentation
        MERGE(hello_world)
        More documentation
      """, print: _print);
      expect(merger.errorsEncountered, isTrue);
      expect(merged, equalsIgnoringWhitespace("""
        Documentation
        ERROR: No such example: hello_world
        More documentation
      """));
      expect(printedError, isTrue);
      
      // BEGIN(hello_world)
      // I'm adding this so that I can run doc_code_merge.dart on itself
      // without encountering errors.
      // END(hello_world)
    });
    
    test('copyAndMergeDirectory should copy the source code and merge in the examples', () {
      // BEGIN(copyAndMergeDirectory)
      // This is the copyAndMergeDirectory example.
      // END(copyAndMergeDirectory)
      //
      // Start of merge
      // MERGE(copyAndMergeDirectory)
      // End of merge

      Directory tempDir = new Directory("").createTempSync();
            
      // Deleting and recreating a temporary directory is just slightly
      // dangerous, but this test won't be running as root.
      merger.deleteFirst = true;

      Directory scriptDirectory = getScriptDirectory();
      
      // expectAsync1 can't be called from within a "then" clause because
      // that won't be called until after all the tests run.
      var checkResults = expectAsync1((bool completed) {
        String scriptFilename = new Path.fromNative(new Options().script).filename;
        Path outputDirectory = new Path.fromNative(tempDir.path);
        Path mergedFile = outputDirectory.append(scriptFilename);
        String mergedSource = new File.fromPath(mergedFile).readAsTextSync(DocCodeMerger.encoding);
        expect(mergedSource, stringContainsInOrder(["Start of merge",
                                                    "This is the copyAndMergeDirectory example.",
                                                    "End of merge"]));

        // XXX: If there is an exception, or something else weird happens, then
        // the temp directory gets leaked. I can't figure out how to do it with
        // this strange mix of async and sync code.
        tempDir.deleteRecursivelySync();
      });
            
      merger.scanDirectoryForExamples(scriptDirectory)
      .chain((result) => merger.copyAndMergeDirectory(scriptDirectory,
          scriptDirectory, tempDir, print: printNothing))
      .then(checkResults);
    });

    test("clearOutputDirectory checks that the output directory doesn't exist", () {
      merger.clearOutputDirectory(new Directory("this_should_not_exist"));
      expect(merger.errorsEncountered, isFalse);
    });
    
    test("clearOutputDirectory complains and exits with error if the directory does exist", () {
      var printedError = false;
      var exited = false;
      
      void _print(String s) {
        expect(s, equals("$scriptName: Could not prepare output directory `${new Directory.current().path}`: Directory already exists\n"
                         "You should either delete it or pass the --delete-first flag"));
        printedError = true;
      }
      
      void _exit(int status) {
        expect(status, 1);
        exited = true;
        throw new Exit();
      }

      expect(() => merger.clearOutputDirectory(new Directory.current(), print: _print, exit: _exit),
          throwsA(new isInstanceOf<Exit>()));
      expect(merger.errorsEncountered, isTrue);
      expect(printedError, isTrue);
      expect(exited, isTrue);
    });
    
    test("clearOutputDirectory should delete the directory if deleteFirst is true", () {
      callWithTemporaryDirectorySync((tempDir) {
        merger.deleteFirst = true;
        merger.clearOutputDirectory(tempDir);
        expect(merger.errorsEncountered, isFalse);        
      });
    });
    
    test("parseArguments accepts exactly 3 positional arguments", () {
      String thisDir = getScriptDirectory().path;
      merger.parseArguments([thisDir, thisDir, "OUTPUT"]);
      expect(merger.errorsEncountered, isFalse);
      expect(merger.documentationDirectory.path, equals(thisDir));
      expect(merger.codeDirectory.path, equals(thisDir));
      expect(merger.outputDirectory.path, equals(new Directory("OUTPUT").path));
    });
    
    test("parseArguments complains if there aren't exactly 3 positional arguments", () {
      var printedError = false;
     
      void _print(String s) {
        expect(s, stringContainsInOrder(["$scriptName: Expected 3 positional arguments",
                                         "usage: $scriptName",
                                         "DOCUMENTATION CODE OUTPUT"]));
        printedError = true;
      }
      
      merger.parseArguments([], print: _print);
      expect(merger.errorsEncountered, isTrue);
      expect(printedError, isTrue);
    });
    
    test("resolveDirectoryOrExit should return an absolute path", () {      
      Directory resolvedDirectory = merger.resolveDirectoryOrExit('.');      
      expect(new Path.fromNative(resolvedDirectory.path).isAbsolute, isTrue);
    });
    
    test("resolveDirectoryOrExit should check that a directory exists or exit with an error", () {
      var printedError;
      var exited;
      
      void _print(String s) {
        expect(s, stringContainsInOrder([scriptName,
                                         "FileIOException: Cannot retrieve full path for file 'this_should_not_exist'"]));
        printedError = true;
      }
      
      void _exit(int status) {
        expect(status, 1);
        exited = true;
        throw new Exit();
      }
      
      expect(() => merger.resolveDirectoryOrExit('this_should_not_exist', print: _print, exit: _exit), 
          throwsA(new isInstanceOf<Exit>()));
      expect(printedError, isTrue);
      expect(exited, isTrue);
    });
    
    test("main should print usage and exit with status of 0 when you call it with --help", () {
      var printedUsage;
      var exited;

      void _print(String s) {
        expect(s, stringContainsInOrder(["usage: $scriptName",
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
        expect(() => merger.main(["--help"], print: _print, exit: _exit),
            throwsA(new isInstanceOf<Exit>()));
        expect(merger.errorsEncountered, isFalse);
        expect(printedUsage, isTrue);
        expect(exited, isTrue);
      });
    });
    
    test("parseArguments can set the --delete-first flag", () {
      expect(merger.deleteFirst, isFalse);
      merger.parseArguments(["--delete-first"], print: printNothing);
      expect(merger.deleteFirst, isTrue);
    });
    
    test("parseArguments should resolve directories", () {
      merger.parseArguments(['.', '.', 'irrelevant']);
      expect(new Path.fromNative(merger.documentationDirectory.path).isAbsolute, isTrue);
      expect(new Path.fromNative(merger.codeDirectory.path).isAbsolute, isTrue);
    });

    test("isPrivate should be false for '.'", () {
      expect(merger.isPrivate(new Path.fromNative('.')), isFalse);      
    });

    test("isPrivate should be true for '..'", () {
      expect(merger.isPrivate(new Path.fromNative('..')), isTrue);      
    });

    test("isPrivate should be true for '.git'", () {
      expect(merger.isPrivate(new Path.fromNative('.git')), isTrue);      
    });
    
    test("isPrivate should be true for 'foo/.git/bar'", () {
      expect(merger.isPrivate(new Path.fromNative('foo/.git/bar')), isTrue);      
    });
    
    test("isPrivate should be false for './foo/bar'", () {
      expect(merger.isPrivate(new Path.fromNative('./foo/bar')), isFalse);      
    });

    test("htmlEscapeFilter escapes HTML", () {
      expect(DocCodeMerger.htmlEscapeFilter(["<blink>", "hi", "</blink>"]),
             equals(["&lt;blink&gt;", "hi", "&lt;/blink&gt;"]));
    });
    
    test("indentFilter idents code", () {
      expect(DocCodeMerger.indentFilter(["Hi", "There"]),
             equals(["  Hi", "  There"]));
    });
    
    test("unindentFilter unindents code", () {
      expect(DocCodeMerger.unindentFilter(["  1",
                                           "  2"]),
             equals(["1",
                     "2"]));
    });
    
    test("unindentFilter unindents code where the first line is indented the most", () {
      expect(DocCodeMerger.unindentFilter(["\t    1",
                                           "\t  2",
                                           "\t    3"]),
             equals(["  1",
                     "2",
                     "  3"]));
    });
    
    test("unindentFilter does nothing for unindented code", () {
      expect(DocCodeMerger.unindentFilter(["1",
                                           "2",
                                           "3"]),
             equals(["1",
                     "2",
                     "3"]));
    });
    
    test("unindentFilter handles empty lists", () {
      expect(DocCodeMerger.unindentFilter([]),
             equals([]));
    });
    
    test("unindentFilter does not try to handle inconsistent indentation", () {
      expect(DocCodeMerger.unindentFilter(["\t1",
                                           "  2",
                                           "    3"
                                           "        4"]),
             equals(["\t1",
                     "  2",
                     "    3"
                     "        4"]));
    });
    
    test("unindentFilter handles really awkward short lines", () {
      expect(DocCodeMerger.unindentFilter(["    1",
                                           "2"]),
             equals(["    1",
                     "2"]));
    });
    
    test("unindentFilter handles blank lines and lines with only indentation", () {
      expect(DocCodeMerger.unindentFilter(["  1",
                                           "",
                                           " ",
                                           "    2"]),
             equals(["1",
                     "",
                     "",
                     "  2"]));
    });
    
    test("getFilters should return the right filters for HTML", () {
      List<Filter> filters = merger.getFilters("index.html");
      List<String> filtered = merger.applyFilters(filters, ["  a > b;",
                                                            "  c(&d);"]);
      expect(filtered, equals(["a &gt; b;",
                               "c(&amp;d);"]));
    });

    test("getFilters should return the right filters for plain text", () {
      List<Filter> filters = merger.getFilters("plain.txt");
      List<String> filtered = merger.applyFilters(filters, ["    >>> Hi",
                                                            "    >>> There!"]);
      expect(filtered, equals(["  >>> Hi",
                               "  >>> There!"]));
    });

    // This test is pretty high level. copyAndMergeDirectory has a test that
    // is more thorough.
    test("main does everything", () {
      Directory scriptDirectory = getScriptDirectory();
      Directory tempDir = new Directory("").createTempSync();
     
      // expectAsync1 can't be called from within a "then" clause because
      // that won't be called until after all the tests run.
      var checkResults = expectAsync1((bool result) {
        
        // XXX: If there is an exception, or something else weird happens, then
        // the temp directory gets leaked. I can't figure out how to do it with
        // this strange mix of async and sync code.
        tempDir.deleteRecursivelySync();
        
        expect(result, isTrue);
      });

      merger.main(["--delete-first", scriptDirectory.path, scriptDirectory.path, tempDir.path], 
          print: printNothing).then(checkResults);
    });    
  });
}