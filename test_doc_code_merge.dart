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
      
      expect(merger.examples["add"].toString().trim(), equals("""
        num add(num a, num b) {
          return a + b;
        }
      """.trim()));
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
      
      expect(merger.examples["one_line"].toString().trim(), equals("""
        line
      """.trim()));

      expect(merger.examples["two_lines"].toString().trim(), equals("""
        line
        line
      """.trim()));
    });
  });
}