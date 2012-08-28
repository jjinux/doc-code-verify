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
    
    test('examples is empty by default', () {
      expect(merger.examples.isEmpty(), isTrue);
    });
    
    test('scanForExamples updates examples', () {      
      merger.scanForExamples("""
        // #BEGIN add
        num add(num a, num b) {
          return a + b;
        }
        // #END add
        
        void main() {
          print("Hello, World!");
        }
      """);
      
      expect(merger.examples["add"].toString(), equalsIgnoringWhitespace("""
        num add(num a, num b) {
          return a + b;
        }
      """));
    });
    
    test('scanForExamples permits overlapping examples', () {
      merger.scanForExamples("""
        // #BEGIN two_lines
        line
        // #BEGIN one_line
        line
        // #END two_lines
        // #END one_line
        line
        line
      """);
      
      expect(merger.examples["one_line"].toString(), equalsIgnoringWhitespace("""
        line
      """));

      expect(merger.examples["two_lines"].toString(), equalsIgnoringWhitespace("""
        line
        line
      """));
    });
    
    test('scanForExamples concatenates examples with the same name', () {
      merger.scanForExamples("""
        // #BEGIN example
        line
        // #END example
        line
        line
        // #BEGIN example
        line
        // #END example
      """);
      
      expect(merger.examples["example"].toString(), equalsIgnoringWhitespace("""
        line
        line
      """));
    });
    
    test('scanDirectoryForExamples can scan this directory for examples', () {
      // #BEGIN thisTestIsSoMeta
      // meta meta meta
      // #END thisTestIsSoMeta
      merger.scanDirectoryForExamples(getScriptDirectory()).then(expectAsync1((completed) {
        expect(merger.examples.length, greaterThan(1));
        expect(merger.examples["thisTestIsSoMeta"].toString(), equalsIgnoringWhitespace("""
          // meta meta meta
        """));
      }));
    });

    test('mergeExamples merges in examples', () {
      merger.scanForExamples("""
        // #BEGIN example
        Source code
        // #END example
      """); 
      String merged = merger.mergeExamples("""
        Documentation
        #MERGE example
        More documentation
      """);
      expect(merged, equalsIgnoringWhitespace("""
        Documentation
        Source code
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
        #MERGE hello_world
        More documentation
      """, print: _print);
      expect(merger.errorsEncountered, isTrue);
      expect(merged, equalsIgnoringWhitespace("""
        Documentation
        ERROR: No such example: hello_world
        More documentation
      """));
      expect(printedError, isTrue);
    });
    
    test('copyAndMergeDirectory should copy the source code and merge in the examples', () {
      // #BEGIN copyAndMergeDirectory
      // This is the copyAndMergeDirectory example.
      // #END copyAndMergeDirectory
      //
      // Start of merge
      // #MERGE copyAndMergeDirectory
      // End of merge

      Directory tempDir = new Directory("").createTempSync();
            
      // Deleting and recreating a temporary directory is just slightly
      // dangerous, but this test won't be running as root.
      merger.deleteFirst = true;

      Directory scriptDirectory = getScriptDirectory();
      
      // expectAsync1 can't be called from within a "then" clause because that won't be called
      // until after all the tests run.
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
    
    test("clearOutputDirectory complains if the directory does exist", () {
      var printedError = false;
      
      void _print(String s) {
        expect(s, equals("$scriptName: Could not prepare output directory `${new Directory.current().path}`: Directory already exists\n"
                         "You should either delete it or pass the --delete-first flag"));
        printedError = true;
      }

      merger.clearOutputDirectory(new Directory.current(), print: _print);
      expect(merger.errorsEncountered, isTrue);
      expect(printedError, isTrue);
    });
    
    test("clearOutputDirectory should delete the directory if deleteFirst is true", () {
      callWithTemporaryDirectorySync((tempDir) {
        merger.deleteFirst = true;
        merger.clearOutputDirectory(tempDir);
        expect(merger.errorsEncountered, isFalse);        
      });
    });
    
    test("parseArguments accepts exactly 3 positional arguments", () {
      merger.parseArguments(["DOCUMENTATION", "CODE", "OUTPUT"]);
      expect(merger.errorsEncountered, isFalse);
      expect(merger.documentationDirectory.path, equals(new Directory("DOCUMENTATION").path));
      expect(merger.codeDirectory.path, equals(new Directory("CODE").path));
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
    
    test("parseArguments can print usage", () {
      var printedUsage;
      
      void _print(String s) {
        expect(s, stringContainsInOrder(["usage: $scriptName",
                                         "DOCUMENTATION CODE OUTPUT"]));
        printedUsage = true;
      }
      
      ["--help", "-h"].forEach((arg) {
        printedUsage = false;
        merger.parseArguments([arg], print: _print);
        expect(merger.errorsEncountered, isFalse);
        expect(printedUsage, isTrue);
      });
    });
    
    test("parseArguments can set the --delete-first flag", () {
      expect(merger.deleteFirst, isFalse);
      merger.parseArguments(["--delete-first"], print: printNothing);
      expect(merger.deleteFirst, isTrue);
    });
  });  
}