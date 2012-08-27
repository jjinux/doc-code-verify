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
    String exampleName;
    lines.forEach((line) {
      Match beginMatch = beginRegExp.firstMatch(line);
      if (beginMatch != null) {
        exampleName = beginMatch[1];
        return;
      }
      
      Match endMatch = endRegExp.firstMatch(line);
      if (endMatch != null) {
        exampleName = null;
        return;
      }
      
      if (exampleName != null) {
        examples.putIfAbsent(exampleName, () => new StringBuffer());
        examples[exampleName].addAll([line, newline]);
      }
    });
  }
}