doc-code-merge
==============

doc-code-merge is a tool to merge source code into documentation. Keeping the
source code separate of the documentation makes it easier to work with and
easier to test. Merging the two can be part of your build process.

Setup
-----

	export DART_SDK=.../dart/dart-sdk
	export PATH=$PATH:$DART_SDK/bin
	pub install
	
	# Put doc_code_merge.dart itself in your PATH.
	export PATH=$PATH:`pwd`/bin

Usage
-----

Start by writing some documentation. You can use either a single file or a
whole file hierarchy. The documentation can have lines that look like this:

	MERGE(my_example_name)

Then create a separate codebase. Again, it can be either a single file or a
whole file hierarchy. Inside the code, you can have examples such as:

	// BEGIN(my_example_name)
	Lots of source code
	// END(my_example_name)

To create a copy of the documentation with examples from the source code
merged into it, run:

	doc_code_merge.dart DOCUMENTATION CODE OUTPUT

DOCUMENTATION and CODE (whether they are files or directories) will not be
changed. OUTPUT will end up with the same structure as DOCUMENTATION.

Details
-------

To get usage, run: doc_code_merge.dart --help

In general, the syntax is line-oriented. I.e. each directive should be on its
own line. However, putting other things on the line, such as comment markers,
is generally okay.

If you want to merge an example in the middle of a line and automatically trim
whitespace around the example, use this syntax (notice the parenthesis around
the MERGE):

	This line shows how to merge a (MERGE(small_example)) inline.

Example names can contain anything, except a closing parenthesis. They can
even contain whitespace, but whitespace is significant!

I plan on making the actual syntax configurable. Naturally, the goal is to
support any text-based documentation format (especially HTML) and any type of
source code (especially Dart).

Example blocks may overlap with one another. If two blocks share the same
name, they'll be concatenated.

Testing
-------

To run the unittests:

	dart --enable-checked-mode test/doc_code_merger_test.dart

TODO
----

Make it possible to configure the syntax.

Make it possible to ignore certain filetypes. E.g. ignore files that aren't
source code.

Make sure it works on simple files as well as directories.

There are some TODO's in the code.

Make sure things get printed to stderr using:
stderr.writeString("Message").

Known Limitations
-----------------

It silently ignores symlinks in the documentation. If you care why, grep for
"symlink" in the source code.

It does not play well with symlink loops. See
(http://code.google.com/p/dart/issues/detail?id=4801).