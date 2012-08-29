#!/usr/bin/env dart

// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library("doc_code_merge");

#import('dart:io');

final scriptName = "doc_code_merge.dart";

/**
 * [DocCodeMerger] merges documentation with code.
 * 
 * See the project README.md for more information.
 * 
 * There's a class-level [main] method that's fairly testable, and there's
 * also a top-level main function that isn't (since it has to deal with
 * the outside world).
 */
class DocCodeMerger {
  static const newlineRegExp = const RegExp(@"\r\n|\r|\n");
  static const beginRegExp = const RegExp(@"#BEGIN +(\w+)");
  static const endRegExp = const RegExp(@"#END +(\w+)");
  static const mergeRegExp = const RegExp(@"#MERGE +(\w+)");
  static const newline = "\n";
  static const encoding = Encoding.UTF_8;
  
  Directory documentationDirectory;
  Directory codeDirectory;
  Directory outputDirectory;
  Map<String, StringBuffer> examples;
  bool errorsEncountered = false;
  bool deleteFirst = false;
  
  DocCodeMerger() {
    examples = new Map<String, StringBuffer>();
  }
  
  /// Scan input for examples and update [examples].
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
   * Scan an entire directory for examples and update [examples].
   * 
   * I'm stuck using an async interface since there is no synchronous interface for Directory.list.
   * See: http://code.google.com/p/dart/issues/detail?id=4730
   */
  Future scanDirectoryForExamples(Directory sourceDirectory) {
    var completer = new Completer();
    DirectoryLister lister = sourceDirectory.list(recursive: true);
    lister.onFile = (String path) {
      Path pathPath = new Path.fromNative(path);  // :)
      if (isPrivate(pathPath)) return;
      Path filenameAsPath = new Path.fromNative(pathPath.filename);
      var sourceCode = new File(path).readAsTextSync(encoding);
      scanForExamples(sourceCode);
    };
    lister.onDone = (done) => completer.complete(true);
    return completer.future;
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
  String mergeExamples(String documentation, [PrintFunction print = print]) {
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
   * Merge the documentation directory and the code directory and create the output directory.
   *  
   * I'm stuck using an async interface since there is no synchronous interface for Directory.list.
   * See: http://code.google.com/p/dart/issues/detail?id=4730
   */
  Future copyAndMergeDirectory(Directory documentation, Directory code,
                               Directory output, [PrintFunction print = print]) {
    clearOutputDirectory(output);
    output.createSync();
    var completer = new Completer();
    DirectoryLister lister = documentation.list(recursive: true);
    Path documentationPath = new Path.fromNative(documentation.path);
    Path outputPath = new Path.fromNative(output.path);
    var writers = new List<Future>();

    // Return the target path. If that's not possible, return null.
    Path getOutputPath(String name) {
      Path path = new Path.fromNative(name);
      Path relativePath;
      
      // DirectoryLister insists on getting the realpath for symlinks, which
      // causes path.relativeTo to fail and raise a NotImplementedException
      // exception. I could complain, but since every Dart application that
      // uses Dart is going to have symlinks in the packages directory,
      // I'm just going to ignore them silently.     
      if (!path.toNativePath().startsWith(documentationPath.toNativePath())) return null;
      relativePath = path.relativeTo(documentationPath);
      
      if (isPrivate(relativePath)) return null;
      return outputPath.join(relativePath);  
    }
    
    lister.onDir = (String docDir) {
      Path outputPath = getOutputPath(docDir);
      if (outputPath == null) return;
      Directory outputDir = new Directory.fromPath(outputPath);
      outputDir.createSync();
    };
    
    lister.onFile = (String docFile) {
      Path outputPath = getOutputPath(docFile);
      if (outputPath == null) return;
      var completer = new Completer();
      writers.add(completer.future);
      String docText = new File(docFile).readAsTextSync(encoding);
      File outputFile = new File.fromPath(outputPath);
      OutputStream outputStream = outputFile.openOutputStream(FileMode.WRITE);
      String outputText = mergeExamples(docText, print: print);
      outputStream.writeString(outputText, encoding);
      outputStream.onClosed = () => completer.complete(true);
      outputStream.close();
    };

    lister.onDone = (done) {
      Futures.wait(writers).then((futures) {
        completer.complete(true);
      });
    };
    return completer.future;    
  }
  
  /**
   * Check that the output directory doesn't exist.
   * 
   * If deleteFirst is true, try to delete the directory if it exists.
   * If deleteFirst is false, and the directory exists, complain and exit.
   */
  void clearOutputDirectory(Directory outputDirectory, [PrintFunction print = print, ExitFunction exit = exit]) {
    if (outputDirectory.existsSync()) {
      if (deleteFirst) {
        outputDirectory.deleteRecursivelySync();
      } else {
        errorsEncountered = true;
        print("$scriptName: Could not prepare output directory `${outputDirectory.path}`: Directory already exists\n"
              "You should either delete it or pass the --delete-first flag");
        exit(1);
        throw new ExpectException("exit should not return");        
      }
    }
  }
  
  /// Parse command-line arguments.
  void parseArguments(List<String> arguments, [PrintFunction print = print,
      ExitFunction exit = exit]) {
    var positionalArguments = <String>[];
    for (var i = 0; i < arguments.length; i++) {
      String arg = arguments[i];
      if (arg == "-h" || arg == "--help") {
        print(getUsage());
        exit(0);
        throw new ExpectException("exit should not return");
      }
      if (arg == "--delete-first") {
        deleteFirst = true;
      }
      if (!arg.startsWith("-")) {
        positionalArguments.add(arg);
      }
    }

    if (positionalArguments.length == 3) {
      documentationDirectory = resolveDirectoryOrExit(positionalArguments[0]);
      codeDirectory = resolveDirectoryOrExit(positionalArguments[1]);
      
      // We can't resolve the outputDirectory yet since it probably doesn't
      // exist. It turns out not to matter since we don't need to use
      // path.relativeTo with the outputDirectory.
      outputDirectory = new Directory(positionalArguments[2]);
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
  Directory resolveDirectoryOrExit(String path, [PrintFunction print = print,
      ExitFunction exit = exit]) {
    try {
      String fullPath = new File(path).fullPathSync();
      return new Directory(fullPath);
    } catch (FileIOException e) {
      print("$scriptName: $e");
      exit(1);
      throw new ExpectException("exit should not return");
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
    return path.segments().some((segment) {
      if (segment == '.') return false;
      if (segment.startsWith('.')) return true; // Including '..'
      return false;
    });  
  }
  
  /// This is a testable version of the main function.
  Future<bool> main(List<String> arguments, [PrintFunction print = print,
      ExitFunction exit = exit]) {
    parseArguments(arguments, print: print, exit: exit);
    var completer = new Completer();
    if (errorsEncountered) {
      completer.complete(false);
    } else {
      scanDirectoryForExamples(codeDirectory)
      .chain((result) => copyAndMergeDirectory(documentationDirectory, 
          codeDirectory, outputDirectory, print: print))
      .then((result) => completer.complete(true));
    }
    return completer.future;
  }
}

/// Basically, create a DocCodeMerger object and call its main method.
void main() {
  var merger = new DocCodeMerger();
  merger.main(new Options().arguments).then((result) {
    exit(merger.errorsEncountered ? 1 : 0);
  }); 
}

/// This is stuff to make testing easier.
typedef void PrintFunction(obj);

/// Take obj and do nothing.
void printNothing(obj) {}

/// If you implement your own ExitFunction, you should throw a new Exit instance.
typedef void ExitFunction(int status);

class Exit implements Exception {}