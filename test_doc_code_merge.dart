#import('dart:io');
#import('package:unittest/unittest.dart');
#import('doc_code_merge.dart');

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
    
    test("prepareOutputDirectory checks that the output directory doesn't exist", () {
      merger.prepareOutputDirectory(new Directory("this_should_not_exist"));
      expect(merger.errorsEncountered, isFalse);
    });
    
    test("prepareOutputDirectory complains if the directory does exist", () {
      var printedError = false;
      
      void _print(String s) {
        expect(s, equals("$scriptName: Could not prepare output directory `${new Directory.current().path}`: Directory already exists\n"
                         "You should either delete it or pass the --delete-first flag"));
        printedError = true;
      }

      merger.prepareOutputDirectory(new Directory.current(), print: _print);
      expect(merger.errorsEncountered, isTrue);
      expect(printedError, isTrue);
    });
    
    test("prepareOutputDirectory should delete the directory if deleteFirst is true", () {
      Directory tempDir = new Directory("").createTempSync();
      try {
        merger.prepareOutputDirectory(tempDir, deleteFirst: true);
        expect(merger.errorsEncountered, isFalse);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteRecursivelySync();
        }
      }      
    });
  });  
}