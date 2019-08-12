---
title: "Multifile development"
description: "An overview of how to load files/include modules or libraries in Imandra"
kernel: imandra
slug: loading-files
key-phrases:
  - loading
  - use
  - mod_use
  - load path
  - import
  - require
  - libraries
---

# Loading files and libraries

Imandra comes with several different directives for loading files or including external modules.

It can be a bit daunting initially to undertstand which directive to use in the appropriate context, let's look at each in detail:

## use

Syntax: `#use "filename.iml";;` or `[@@@use "filename.iml"]`

The behavior of `use` is that of reading the content of `"filename.iml"` and evaluating it into the current environment, as if each definition had been directly entered into the toplevel.

The `use` directive is meant to used in interactive sessions rather than in library/production code, and is not recursive.

There exist a functional equivalent of the directive, called `System.use` that can be used to (recursively) load files at runtime, this is often useful to implement the common pattern of having a `top.iml` file responsible for loading the entire model one is working on, or more generally for programmatic loading of imandra files.

If `filename.iml` is a relative path, it is resolved to an absolute path by searching for it in Imandra's _load path_.

The current directory is always implicitly part of the load path, and additional directories can be added dynamically via the `directory` directive, or at startup using the `-dir` argument.

## mod_use

Syntax: `#mod_use "filename.iml";;` or `[@@@mod_use "filename.iml"]`

`mod_use` behaves exactly like `use`, with the only exception that the contents of the file will be evaluated in the toplevel as if they were wrapped in a module called `Filename`

The functional equivalent of the directive is `System.mod_use`

## use_gist

Syntax: `#use_gist "my-user/gist-hash";;` or `[@@@use_gist "my-user/gist-hash"]`

`use_gist` behaves exactly like `use`, except instead of loading a local path it will download the gist content and load that in the current environment.

## import

Syntax: `#import "filename.iml";;` or `[@@@import "filename.iml"]`

The behavior of `import` is similar to that of `mod_use`, with a number of significant differences:

- toplevel directives are disabled in the file being imported
- `import` is idempotent, as it caches on first import
- Imandra resolves the import at compile time, so the imported module is available when typechecking the remainder of the file

As such, `import` can be considered a version of `mod_use` to be used in IML libraries as opposed to during interactive development.

Like `use` and `mod_use`, `import` uses Imandra's _load path_ to search for files, when importing an IML library, the current directory will be temporary set to that of the library itself.

## require

Syntax: `#require "some-lib";;` or `[@@@require "some-lib"]` or as an argument to imandra: `-require somelib`

The behavior of `require` is to search for `some-lib` in the list of installed libraries (using topfind) and load it in the current environment.

If `some-lib` comes packaged with a `some-lib.iml` file, it will be automatically loaded by Imandra after the library has been required.
