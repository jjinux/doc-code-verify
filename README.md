doc-code-merge
==============

doc-code-merge is a tool to merge source code into documentation. Keeping the
source code separate of the documentation makes it easier to work with and
easier to test. Merging the two can be part of your build process.

Usage
-----

Start by writing some documentation. You can use either a single file or a
whole file hierarchy. The documentation can have lines that look like this:

	#MERGE my_example_name

Then create a separate codebase. Again, it can be either a single file or a
whole file hierarchy. Inside the code, you can have examples such as:

	// #BEGIN my_example_name
	Lots of source code
	// #END my_example_name

Example blocks may overlap with one another. If two blocks share the same
name, they'll be concatenated.

The syntax is line-oriented. I.e. each directive should be on
its own line. However, putting other things on the line, such as comment
markers, is generally okay.

I plan to make the actual syntax configurable. Naturally, the goal is to
support any text-based documentation format (especially HTML) and any type of
source code (especially Dart).

Now, setup your environment:

	export DART_SDK=.../dart/dart-sdk
	export PATH=$PATH:$DART_SDK/bin
	pub install

	# HACK: Work around: http://code.google.com/p/dart/issues/detail?id=4801
	rm packages/doc-code-merge

To create a copy of the documentation with examples from the source code
merged into it, run:

	dart doc_code_merge.dart DOCUMENTATION CODE OUTPUT

DOCUMENTATION and CODE (whether they are files or directories) will not be
changed. OUTPUT will end up with the same structure as DOCUMENTATION. If
doc_code_merge.dart already exists, doc_code_merge.dart will ask you to either
delete it or pass the --delete-first flag (which will delete it for you).

Developing
----------

To work on doc-code-merge, you'll need to set DartEditor >> Preferences >>
Editor >> Package directory to doc-code-merge/packages.

Testing
-------

To run the unittests:

	dart test_doc_code_merge.dart

TODO
----

It can't handle non-absolute directory names. Use File.fullPathSync to fix
this.

Handle symlinks in the documentation or code. Get rid of the place where I'm
catching an exception to work around symlinks.

It gets hopelessly confused by symlink loops. See
(http://code.google.com/p/dart/issues/detail?id=4801). See also the "HACK" in
this file.

Make it possible to configure the syntax.

Support HTML output by wrapping the code in a pre block and HTML escaping it.

Make it possible to ignore certain filetypes. E.g. ignore files that aren't
source code.

Make sure it works on simple files as well as directories.

Don't use # because it conflicts with Markdown.

We currently have the problem that some of our documentation is in Markdown
and some of it is in Docbook (which is XML). We have to behave differently for
those two formats. For instance, when outputting XML, we need to escape the
code. We also might want to wrap the code differently based on what we're
generating (although Seth prefers to do the wrapping by hand).

This code is better than what I have:

	Path get scriptDir() =>
      new Path.fromNative(new Options().script).directoryPath;

That may also help get rid of my hard-coded scriptName.

We need to be able to merge examples in the middle of a line with no spurious
whitespace, such as:

	Simple one-liner <!-- MERGE oneLiner -->, and so is...

There are some XXX's in the code.