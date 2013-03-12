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
  
  /**
   * This is a list of filter rules.
   *
   * Each filter rule is applied in order. The first one that matches gets
   * used.
   */
  static final List<FilterRule> filterRules = [
    new FilterRule(new RegExp(r"\.(html|xml)$"), [unindentFilter, htmlEscapeFilter]),
    new FilterRule(new RegExp(r".*$"), [unindentFilter, indentFilter])
  ];

  Directory documentationDirectory;
  Directory codeDirectory;
  bool errorsEncountered = false;
  bool deleteFirst = false;

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
        openExamples.add(beginMatch[1]);
        return;
      }

      Match endMatch = endRegExp.firstMatch(line);
      if (endMatch != null) {
        var name = endMatch[1];
        if (!openExamples.remove(name)) {
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
   * Verify examples into the given documentation and return it.
   *
   * Remember, there are two types of verify statements:
   *
   *  - Verify blocks
   *  - Inline verifys
   */
  String verifyExamples(String documentation,
                       {List<Filter> filters: const [], PrintFunction print: print}) {
    List<String> lines = documentation.split(newlineRegExp);
    var output = new List<String>();
    lines.forEach((line) {

      // Look for inline verifys first since they take precedence. There may
      // be more than one inline verify per line.
      if (inlineVerifyRegExp.hasMatch(line)) {
        var tokenizer = new RegExp("${inlineVerifyRegExp.pattern}|(.)");
        var linePieces = new List<String>();
        for (var match in tokenizer.allMatches(line)) {
          String piece = match.group(0);

          // If it's a standalone character, just append it to linePieces.
          if (piece.length == 1) {
            linePieces.add(piece);
          }

          // Otherwise, it's time to do a verify.
          else {
            String exampleName = match[1];
            List<String> lines = lookupExample(exampleName,
                filters: filters, print: print);

            // Make a copy, and trim the last line so that it verifys inline cleanly.
            lines = new List<String>.from(lines);
            lines[lines.length - 1] = rtrim(lines[lines.length - 1]);

            // Don't use a newline on the last line.
            String joined = lines.join(newline);
            linePieces.add(joined);
          }
        }

        String fullLine = linePieces.join();
        output.add("$fullLine$newline");
        return;
      }

      // Now look for verify blocks.
      Match match = verifyBlockRegExp.firstMatch(line);
      if (match != null) {
        String exampleName = match[1];
        List<String> lines = lookupExample(exampleName,
            filters: filters, print: print);
        for (var line in lines) {
          output.add("$line$newline");
        }
        return;
      }

      // If this isn't a verify line, just copy the line over unmodified.
      output.add("$line$newline");
    });

    return output.join();
  }

  /**
   * Lookup the given example and return it after applying filters.
   *
   * If the documentation refers to an example that doesn't exist:
   *
   *  - Set errorsEncountered to true
   *  - Print an error message
   *  - Translate the example to an error message
   */
  List<String> lookupExample(String exampleName,
      {List<Filter> filters: const [], PrintFunction print: print}) {
    List<String> example = examples[exampleName];
    List<String> lines;

    // Complain if we can't find the right example.
    if (example == null) {
      errorsEncountered = true;
      var error = "No such example: $exampleName";
      print("$scriptName: $error");
      lines = ["ERROR: $error$newline"];
    }

    // Otherwise, use the example we found.
    else {
      lines = example;
    }

    // Make sure to apply filters.
    return applyFilters(filters, lines);
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
      if (arg == "--delete-first") {
        deleteFirst = true;
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

  static List<String> htmlEscapeFilter(List<String> lines) {
    return new List.from(lines.map(htmlEscape));
  }

  static List<String> indentFilter(List<String> lines) {
    return new List.from(lines.map((s) => "$indentation$s"));
  }

  /**
   * Remove the indentation from the given lines.
   *
   * Only remove as much indentation as the line with the least amount of
   * indentation.
   */
  static List<String> unindentFilter(List<String> lines) {
    // Make a copy so that we can modify it in place.
    lines = new List<String>.from(lines);

    // Make sure there is at least one line.
    if (!lines.isEmpty) {

      // Figure out how much indentation the first line has.
      var indentation = new List<String>();
      for (String char in lines[0].split("")) {
        if (char == " " || char == "\t") {
          indentation.add(char);
        } else {
          break;
        }
      }

      // Figure out the least amount of indentation any of the other lines has.
      for (var i = 1; i < lines.length; i++) {
        String line = lines[i];
        List<String> chars = line.split("");

        // Lines that only have whitespace should be set to "" and ignored.
        var whitespaceOnly = true;
        for (var char in chars) {
          if (char != " " && char != "\t") {
            whitespaceOnly = false;
            break;
          }
        }
        if (whitespaceOnly) {
          lines[i] = "";
        } else {

          // If the line has something other than whitespace, see how its
          // indentation compares to the least amount of indentation we've
          // seen so far.
          for (var j = 0; j < indentation.length && j < chars.length; j++) {
            String char = chars[j];
            if ((char != " " && char != "\t") ||
                char != indentation[j]) {

              // We found a new line with less indentation.
              indentation.removeRange(j, indentation.length - j);
              break;
            }
          }
        }
      }

      // Loop over all the lines, and remove the right amount of indentation.
      for (var i = 0; i < lines.length; i++) {
        String line = lines[i];

        // Ignore blank lines.
        if (line != "") {

          // Otherwise, trim off the right amount of indentation.
          List<String> chars = line.split("");
          List<String> unindented = chars.getRange(indentation.length, chars.length - indentation.length);
          lines[i] = unindented.join();
        }
      }
    }

    return lines;
  }

  /// Given a filename, return a list of filters appropriate for that file.
  List<Filter> getFilters(String filename) {
    for (var rule in filterRules) {
      if (rule.regExp.hasMatch(filename)) {
        return rule.filters;
      }
    }
    return [];
  }

  /// Apply a list of filters to a list of lines.
  List<String> applyFilters(List<Filter> filters, List<String> lines) {
    for (var filter in filters) {
      lines = filter(lines);
    }
    return lines;
  }

  /// This is a testable version of the main function.
  void main(List<String> arguments, {PrintFunction print: print,
      ExitFunction exit: exit}) {
    parseArguments(arguments, print: print, exit: exit);
    if (errorsEncountered) return;
    scanDirectoryForExamples(codeDirectory);
  }
}

/**
 * Escapes HTML-special characters of [text] so that the result can be
 * included verbatim in HTML source code, either in an element body or in an
 * attribute value.
 */
String htmlEscape(String text) {
  return text.replaceAll("&", "&amp;")
             .replaceAll("<", "&lt;")
             .replaceAll(">", "&gt;")
             .replaceAll('"', "&quot;")
             .replaceAll("'", "&apos;");
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

/// Return s without the beginning whitespace.
String ltrim(String s) {
  return s.replaceFirst(new RegExp(r"^\s+"), "");
}

/// Return s without the trailing whitespace.
String rtrim(String s) {
  return s.replaceFirst(new RegExp(r"\s+$"), "");
}