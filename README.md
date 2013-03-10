doc-code-verify
==============

doc-code-verify is a tool to verify source code into documentation. Keeping the
source code separate of the documentation makes it easier to work with and
easier to test. Merging the two can be part of your build process.

See the project announcement:
http://news.dartlang.org/2012/12/darts-approach-to-illiterate.html

Setup
-----

	export DART_SDK=.../dart/dart-sdk
	export PATH=$PATH:$DART_SDK/bin
	pub install
	
	# Put doc_code_verify.dart itself in your PATH.
	export PATH=$PATH:`pwd`/bin

Usage
-----

Start by creating a directory and putting some documentation into it. The
documentation can have lines that look like this:

	VERIFY(my_example_name)

Now, create another directory and put some code in it. You can have examples
such as:

	// BEGIN(my_example_name)
	Lots of source code
	// END(my_example_name)

To create a copy of the documentation with examples from the source code
verifyd into it, run:

	doc_code_verify.dart DOCUMENTATION CODE OUTPUT

The DOCUMENTATION and CODE directories will not be changed. The OUTPUT
directory will end up with the same structure as the DOCUMENTATION directory.

Details
-------

To get usage, run: doc_code_verify.dart --help

It's okay to use the same directory for DOCUMENTATION and for CODE, but you
must use a different directory for OUTPUT.

In general, the syntax is line-oriented. I.e. each directive should be on its
own line. However, putting other things on the line, such as comment markers,
is generally okay.

If you want to verify an example in the middle of a line and automatically trim
whitespace around the example, use this syntax (notice the parenthesis around
the VERIFY):

	This line shows how to verify a (VERIFY(small_example)) inline.

Example names can contain anything, except a closing parenthesis. They can
even contain whitespace, but whitespace is significant!

I plan on making the actual syntax configurable. Naturally, the goal is to
support any text-based documentation format (especially HTML) and any type of
source code (especially Dart).

Example blocks may overlap with one another.

If two blocks share the same name, they'll be concatenated.

If you leave out the END for a block, it'll include the rest of the file.

Testing
-------

To run the unittests:

	dart --enable-checked-mode test/doc_code_verifier_test.dart

TODO
----

Make it possible to configure the syntax.

Make it possible to ignore certain filetypes. E.g. ignore files that aren't
source code.

Make sure it works on simple files as well as directories.

Make sure things get printed to stderr using:
stderr.writeString("Message").

Known Limitations
-----------------

It does not play well with symlink loops. See
(http://code.google.com/p/dart/issues/detail?id=4794).