#library("doc_code_merge");

class DocCodeMerger {
  static final newlineRegExp = const RegExp(@"\r\n|\r|\n");
  static final beginRegExp = const RegExp(@"#BEGIN +(\w+)");
  static final endRegExp = const RegExp(@"#END +(\w+)");
  static final newline = "\n";
  
  Map<String, StringBuffer> examples;
  
  DocCodeMerger() {
    examples = new Map<String, StringBuffer>();
  }
  
  /// Scan input for examples and update `examples`.
  void scanForExamples(String input) {
    List<String> lines = input.split(newlineRegExp);
    var openExamples = new Set<String>();
    lines.forEach((line) {

      Match beginMatch = beginRegExp.firstMatch(line);
      if (beginMatch != null) {
        openExamples.add(beginMatch[1]);
        return;
      }
      
      Match endMatch = endRegExp.firstMatch(line);
      if (endMatch != null) {
        openExamples.remove(endMatch[1]);
        return;
      }
      
      if (!openExamples.isEmpty()) {
        openExamples.forEach((exampleName) {
          examples.putIfAbsent(exampleName, () => new StringBuffer());
          examples[exampleName].addAll([line, newline]);
        });
      }
    });
  }
}