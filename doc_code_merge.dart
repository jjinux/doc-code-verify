#library("doc_code_merge");

class DocCodeMerger {
  static final newlineRegExp = const RegExp(@"\r\n|\r|\n");
  static final beginRegExp = const RegExp(@"#BEGIN +(\w+)");
  static final endRegExp = const RegExp(@"#END +(\w+)");
  static final mergeRegExp = const RegExp(@"#MERGE +(\w+)");
  static final newline = "\n";
  
  Map<String, StringBuffer> examples;
  bool errorsEncountered = false;
  
  DocCodeMerger() {
    examples = new Map<String, StringBuffer>();
  }
  
  /// Scan input for examples and update `examples`.
  void scanForExamples(String sourceCode) {
    List<String> lines = sourceCode.split(newlineRegExp);
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
  
  /**
   * Merge examples into the given documentation and return it.
   * 
   * If the documentation refers to an example that doesn't exist:
   * 
   *  - Set errorsEncountered to true
   *  - Print an error message
   *  - Put an error message in the documentation
   */
  String mergeExamples(String documentation, [print = print]) {
    List<String> lines = documentation.split(newlineRegExp);
    var output = new StringBuffer();
    lines.forEach((line) {
        
      Match mergeMatch = mergeRegExp.firstMatch(line);
      if (mergeMatch != null) {
        String exampleName = mergeMatch[1];
        StringBuffer example = examples[exampleName];
        
        if (example == null) {
          errorsEncountered = true;
          var error = "ERROR: No such example: $exampleName";
          print(error);
          output.addAll([error, newline]);
        } else {
          output.add(example.toString());
        }
        
        return;
      }
      output.addAll([line, newline]);
    });
    return output.toString();
  }
}