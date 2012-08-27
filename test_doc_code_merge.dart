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
        expect(s, equals("ERROR: No such example: hello_world"));
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
  });  
}