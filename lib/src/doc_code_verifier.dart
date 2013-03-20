// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of doc_code_verifier;

/**
 * [DocCodeVerifier] verifys documentation with code.
 *
 * See the project README.md for more information.
 *
 * There's a class-level [main] method that's fairly testable, and there's
 * also a top-level main function that isn't (since it has to deal with
 * the outside world).
 */
class DocCodeVerifier {
  static final newlineRegExp = new RegExp(r"\r\n|\r|\n");
  static final beginRegExp = new RegExp("BEGIN$nameInParens");
  static final endRegExp = new RegExp("END$nameInParens");
  static final verifyBlockRegExp = new RegExp("VERIFY$nameInParens");
  static final inlineVerifyRegExp = new RegExp("\\(VERIFY$nameInParens\\)");
  static const nameInParens = r"\(([^)]+)\)";
  static const newline = "\n";
  static const encoding = Encoding.UTF_8;
  static const indentation = "\t";
  String scriptName;
  
  Directory documentationDirectory;
  Directory codeDirectory;
  bool errorsEncountered = false;

  /// Each example has a name and a list of lines.
  Map<String, List<String>> examples;

  DocCodeVerifier({this.scriptName: "doc_code_verify.dart"}) {
    examples = new Map<String, List<String>>();
  }

  /// Scan input for examples and update [examples].
  void scanForExamples(String sourceCode, {PrintFunction print: print}) {
    List<String> lines = sourceCode.split(newlineRegExp);
    var openExamples = new Set<String>();
    lines.forEach((line) {

      Match beginMatch = beginRegExp.firstMatch(line);
      if (beginMatch != null) {
        var exampleName = beginMatch[1];
        if (examples.containsKey(exampleName)) {
          print("Warning '$exampleName' was already used");
        }
        else {
          openExamples.add(beginMatch[1]);
        }
        return;
      }

      Match endMatch = endRegExp.firstMatch(line);
      if (endMatch != null) {
        var name = endMatch[1];
        openExamples.remove(name); 
        if(!examples.containsKey(name)){
          errorsEncountered = true;
          print("$scriptName: BEGIN for `$name` not found; spelling error?");
        }
        return;
      }

      if (!openExamples.isEmpty) {
        openExamples.forEach((exampleName) {
          examples.putIfAbsent(exampleName, () => new List<String>());
          examples[exampleName].add(line);
        });
      }
    });
  }
  
  /// Scan input for examples, verify in [examples].
  void verifyExamples(String sourceCode, {PrintFunction print: print}) {
    List<String> lines = sourceCode.split(newlineRegExp);
    var examplesToVerify = new Map<String, List<String>>();
    var openExamples = new Set<String>();
    lines.forEach((line) {

      Match beginMatch = beginRegExp.firstMatch(line);
      if (beginMatch != null) {
        openExamples.add(beginMatch[1]);
        return;
      }

      Match endMatch = endRegExp.firstMatch(line);
      if (endMatch != null) {
        var name = endMatch[1];
        openExamples.remove(name);
        if (examples.containsKey(name) && examplesToVerify.containsKey(name)){
          var exampleToVerify = collapseWhitespace(examplesToVerify[name].join());
          var sourceExample = collapseWhitespace(examples[name].join());
          if (exampleToVerify != sourceExample){
              errorsEncountered = true;
              print("'$name' in documentation did not match '$name' in the source code");
          }
        }
        else if(!examples.containsKey(name)){
          errorsEncountered = true;
          print ("'$name' not found in code directory.");
        }
        return;
      }

      if (!openExamples.isEmpty) {
        openExamples.forEach((exampleName) {
          examplesToVerify.putIfAbsent(exampleName, () => new List<String>());
          examplesToVerify[exampleName].add(line);
        });
      }
    });
    openExamples.forEach((exampleName) {
      errorsEncountered = true;
      print("$scriptName: END for `$exampleName` not found; spelling error?");
    });
  }

  /**
   * Scan an entire directory for examples and update [examples].
   * 
   * Because of the way pub uses symlinks, it's common to see the same file
   * multiple times. Ignore files we've already seen.
   */
  void scanDirectoryForExamples(Directory sourceDirectory) {
    var pathsSeen = new Set<String>();
    for (FileSystemEntity fse in sourceDirectory.listSync(recursive: true)) {
      if (!(fse is File)) continue;
      String path = fse.fullPathSync();
      if (pathsSeen.contains(path)) continue;
      pathsSeen.add(path);
      Path pathPath = new Path(path);  // :)
      if (isPrivate(pathPath)) continue;
      var sourceCode = new File(path).readAsStringSync(encoding);
      scanForExamples(sourceCode);
    }

    // This is used in a test. It only works if I put it in the lib directory.
    // BEGIN(symlinkExample)
    // 1
    // END(symlinkExample)
  }
  
  /**
   * Scan an entire directory for examples and verify they already exist in [examples].
   * 
   * Because of the way pub uses symlinks, it's common to see the same file
   * multiple times. Ignore files we've already seen.
   */
  void verifyDirectoryForExamples(Directory documentationDirectory) {
    var pathsSeen = new Set<String>();
    for (FileSystemEntity fse in documentationDirectory.listSync(recursive: true)) {
      if (!(fse is File)) continue;
      String path = fse.fullPathSync();
      if (pathsSeen.contains(path)) continue;
      pathsSeen.add(path);
      Path pathPath = new Path(path);  // :)
      if (isPrivate(pathPath)) continue;
      var sourceCode = new File(path).readAsStringSync(encoding);
      verifyExamples(sourceCode);
    }
  }

  /// Parse command-line arguments.
  void parseArguments(List<String> arguments, {PrintFunction print: print,
      ExitFunction exit: exit}) {
    var positionalArguments = <String>[];
    for (var i = 0; i < arguments.length; i++) {
      String arg = arguments[i];
      if (arg == "-h" || arg == "--help") {
        print(getUsage());
        exit(0);
        throw "exit should not return";
      }
      if (!arg.startsWith("-")) {
        positionalArguments.add(arg);
      }
    }

    if (positionalArguments.length == 2) {
      documentationDirectory = resolveDirectoryOrExit(positionalArguments[0]);
      codeDirectory = resolveDirectoryOrExit(positionalArguments[1]);
    } else {
      errorsEncountered = true;
      print("$scriptName: Expected 3 positional arguments\n${getUsage()}");
    }
  }

  /**
   * Resolve path to an absolute path and return a Directory.
   *
   * If that's not possible, complain and exit with an error.
   */
  Directory resolveDirectoryOrExit(String path, {PrintFunction print: print,
      ExitFunction exit: exit}) {
    try {
      String fullPath = new File(path).fullPathSync();
      return new Directory(fullPath);
    } on FileIOException catch(e) {
      print("$scriptName: $e");
      exit(1);
      throw "exit should not return";
    }
  }

  /// Return usage information.
  String getUsage() {
    return "usage: $scriptName [-h] [--help] [--delete-first] DOCUMENTATION CODE OUTPUT";
  }

  /**
   * Return true if the path has a component that starts with ".".
   *
   * We want to ignore files like .DS_Store and directories like .git.
   */
  bool isPrivate(Path path) {
    return path.segments().any((segment) {
      if (segment == '.') return false;
      if (segment.startsWith('.')) return true; // Including '..'
      return false;
    });
  }
  
  /**
   * Utility function to collapse whitespace runs to single spaces
   * and strip leading/trailing whitespace.
   */
  String collapseWhitespace(_string) {
    bool isWhitespace(String ch) => (' \n\r\t'.indexOf(ch) >= 0);
    StringBuffer result = new StringBuffer();
    bool skipSpace = true;
    for (var i = 0; i < _string.length; i++) {
      var character = _string[i];
      if (isWhitespace(character)) {
        if (!skipSpace) {
          result.write(' ');
          skipSpace = true;
        }
      } else {
        result.write(character);
        skipSpace = false;
      }
    }
    return result.toString().trim();
  }
  
  /// This is a testable version of the main function.
  void main(List<String> arguments, {PrintFunction print: print,
      ExitFunction exit: exit}) {
    parseArguments(arguments, print: print, exit: exit);
    if (errorsEncountered) return;
    scanDirectoryForExamples(codeDirectory);
    verifyDirectoryForExamples(documentationDirectory);
  }
}

/// This is stuff to make testing easier.
typedef void PrintFunction(obj);

/// Take obj and do nothing.
void printNothing(obj) {}

/// If you implement your own ExitFunction, you should throw a new Exit instance.
typedef void ExitFunction(int status);

class Exit implements Exception {}

/// A filter takes a list of lines and returns a list of lines.
typedef List<String> Filter(List<String> lines);

/**
 * A filter rule contains two things:
 *
 *  - A RegExp to match against file names
 *  - A list of filters to apply
 */
class FilterRule {
  final RegExp regExp;
  final List<Filter> filters;
  const FilterRule(this.regExp, this.filters);
}