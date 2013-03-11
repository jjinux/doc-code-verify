doc-code-verify
==============

doc-code-verify is a tool to verify source code in the documentation. It checks
that all code snippets in the documentaion are also in the code source thus ensuring
that the documentation is always up to date.

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

	// BEGIN(my_example_name)
	Source code
	// END(my_example_name)

Now, create another directory and put some code in it. You can have examples
such as:

	// BEGIN(my_example_name)
	Source code
	// END(my_example_name)

doc-code-verify will check that the given source code between the begin and end
tags are identical for each example. If there are any differences, doc-code-verify
display the two versions and allow the user to make corrections accordingly.
The DOCUMENTATION and CODE directories will not be changed.

Details
-------

To get usage, run: doc_code_verify.dart --help

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