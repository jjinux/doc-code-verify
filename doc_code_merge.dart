#library("doc_code_merge");
#import('dart:io');

final scriptName = "doc_code_merge.dart";

class DocCodeMerger {
  static final newlineRegExp = const RegExp(@"\r\n|\r|\n");
  static final beginRegExp = const RegExp(@"#BEGIN +(\w+)");
  static final endRegExp = const RegExp(@"#END +(\w+)");
  static final mergeRegExp = const RegExp(@"#MERGE +(\w+)");
  static final newline = "\n";
  
  Directory documentationDirectory;
  Directory codeDirectory;
  Directory outputDirectory;
  Map<String, StringBuffer> examples;
  bool errorsEncountered = false;
  bool deleteFirst = false;
  
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
          var error = "No such example: $exampleName";
          print("$scriptName: $error");
          output.addAll(["ERROR: $error", newline]);
        } else {
          output.add(example.toString());
        }
        
        return;
      }
      output.addAll([line, newline]);
    });
    return output.toString();
  }
  
  /**
   * Check that the output directory doesn't exist.
   * 
   * If deleteFirst is true, try to delete the directory if it exists.
   */
  void prepareOutputDirectory(Directory outputDirectory, [print = print]) {
    if (outputDirectory.existsSync()) {
      if (deleteFirst) {
        outputDirectory.deleteRecursivelySync();
      } else {
        errorsEncountered = true;
        print("$scriptName: Could not prepare output directory `${outputDirectory.path}`: Directory already exists\n"
              "You should either delete it or pass the --delete-first flag");
      }
    }
  }
  
  /// Parse command-line arguments.
  void parseArguments(List<String> arguments, [print = print]) {
    var positionalArguments = <String>[];
    for (var i = 0; i < arguments.length; i++) {
      String arg = arguments[i];
      if (arg == "-h" || arg == "--help") {
        print(getUsage());
        return;
      }
      if (arg == "--delete-first") {
        deleteFirst = true;
      }
      if (!arg.startsWith("-")) {
        positionalArguments.add(arg);
      }
    }

    if (positionalArguments.length == 3) {
      documentationDirectory = new Directory(positionalArguments[0]);
      codeDirectory = new Directory(positionalArguments[1]);
      outputDirectory = new Directory(positionalArguments[2]);
    } else {
      errorsEncountered = true;
      print("$scriptName: Expected 3 positional arguments\n${getUsage()}");
    }
  }
  
  /// Return usage information.
  String getUsage() {
    return """\
usage: $scriptName [-h] [--help] [--delete-first] DOCUMENTATION CODE OUTPUT""";
  }
}