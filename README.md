# HLint [![Hackage version](https://img.shields.io/hackage/v/hlint.svg?style=flat)](https://hackage.haskell.org/package/hlint) [![Build Status](https://img.shields.io/travis/ndmitchell/hlint.svg?style=flat)](https://travis-ci.org/ndmitchell/hlint)

HLint is a tool for suggesting possible improvements to Haskell code. These suggestions include ideas such as using alternative functions, simplifying code and spotting redundancies. You can try HLint online at [lpaste.net](http://lpaste.net/) - suggestions are shown at the bottom. This document is structured as follows:

* [Installing and running HLint](#installing-and-running-hlint)
* [FAQ](#faq)
* [Customizing the hints](#customizing-the-hints)

### Acknowledgements

This program has only been made possible by the presence of the [haskell-src-exts](https://github.com/haskell-suite/haskell-src-exts) package, and many improvements have been made by [Niklas Broberg](http://www.nbroberg.se) in response to feature requests. Additionally, many people have provided help and patches, including Lennart Augustsson, Malcolm Wallace, Henk-Jan van Tuyl, Gwern Branwen, Alex Ott, Andy Stewart, Roman Leshchinskiy, Johannes Lippmann, Iustin Pop, Steve Purcell and others.

### Bugs and limitations

Bugs can be reported [on the bug tracker](https://github.com/ndmitchell/hlint/issues). There are some issues that I do not intend to fix:

* HLint operates on each module at a time in isolation, as a result HLint does not know about types or which names are in scope.
* The presence of `seq` may cause some hints (i.e. eta-reduction) to change the semantics of a program.
* Either the monomorphism restriction, or rank-2 types, may cause transformed programs to require type signatures to be manually inserted.
* The `RebindableSyntax` extension can cause HLint to suggest incorrect changes.
* HLint turns on many language extensions so it can parse more documents, occasionally some break otherwise legal syntax - e.g. `{-#INLINE foo#-}` doesn't work with `MagicHash`. These extensions can be disabled with `-XNoMagicHash`.

## Installing and running HLint

Installation follows the standard pattern of any Haskell library or program, type `cabal update` to update your local hackage database, then `cabal install hlint` to install HLint.

Once HLint is installed, run hlint source where source is either a Haskell file, or a directory containing Haskell files. A directory will be searched recursively for any files ending with .hs or .lhs. For example, running HLint over darcs would give:


    $ hlint darcs-2.1.2

    darcs-2.1.2\src\CommandLine.lhs:94:1: Error: Use concatMap
    Found:
      concat $ map escapeC s
    Why not:
      concatMap escapeC s

    darcs-2.1.2\src\CommandLine.lhs:103:1: Warning: Use fewer brackets
    Found:
      ftable ++ (map (\ (c, x) -> (toUpper c, urlEncode x)) ftable)
    Why not:
      ftable ++ map (\ (c, x) -> (toUpper c, urlEncode x)) ftable

    darcs-2.1.2\src\Darcs\Patch\Test.lhs:306:1: Error: Use a more efficient monadic variant
    Found:
      mapM (delete_line (fn2fp f) line) old
    Why not:
      mapM_ (delete_line (fn2fp f) line) old

    ... lots more suggestions ...

Each suggestion says which file/line the suggestion relates to, how serious the issue is, a description of the issue, what it found, and what you might want to replace it with. In the case of the first hint, it has suggested that instead of applying `concat` and `map` separately, it would be better to use the combination function `concatMap`.

The first suggestion is marked as an error, because using `concatMap` in preference to the two separate functions is always desirable. In contrast, the removal of brackets is probably a good idea, but not always. Reasons that a hint might be a warning include requiring an additional import, something not everyone agrees on, and functions only available in more recent versions of the base library.

**Bug reports:** The suggested replacement should be equivalent - please report all incorrect suggestions not mentioned as known limitations.

### Reports

HLint can generate a lot of information, making it difficult to search for particular types of errors. The `--report` flag will cause HLint to generate a report file in HTML, which can be viewed interactively. Reports are recommended when there are more than a handful of hints.

### Language Extensions

HLint enables most Haskell extensions, disabling only those which steal too much syntax (currently Arrows, TransformListComp, XmlSyntax and RegularPatterns). Individual extensions can be enabled or disabled with, for instance, `-XArrows`, or `-XNoMagicHash`. The flag `-XHaskell98` selects Haskell 98 compatibility.

### Emacs Integration

Emacs integration has been provided by [Alex Ott](http://xtalk.msk.su/~ott/). The integration is similar to compilation-mode, allowing navigation between errors. The script is at [hs-lint.el](https://github.com/ndmitchell/hlint/blob/master/data/hs-lint.el), and a copy is installed locally in the data directory. To use, add the following code to the Emacs init file:

    (require 'hs-lint)
    (defun my-haskell-mode-hook ()
       (local-set-key "\C-cl" 'hs-lint))
    (add-hook 'haskell-mode-hook 'my-haskell-mode-hook)

### GHCi Integration

GHCi integration has been provided by Gwern Branwen. The integration allows running `:hlint` from the GHCi prompt. The script is at [hlint.ghci](http://community.haskell.org/~ndm/darcs/hlint/data/hlint.ghci), and a copy is installed locally in the data directory. To use, add the contents to your [GHCi startup file](http://www.haskell.org/ghc/docs/latest/html/users_guide/ghci-dot-files.html).

### Parallel Operation

To run HLint on n processors append the flags `+RTS -Nn`, as described in the [GHC user manual](http://www.haskell.org/ghc/docs/latest/html/users_guide/runtime-control.html). HLint will usually perform fastest if n is equal to the number of physical processors.

If your version of GHC does not support the GHC threaded runtime then install with the command: `cabal install --flags="-threaded"`

### C preprocessor support

HLint runs the [cpphs C preprocessor](http://hackage.haskell.org/package/cpphs) over all input files, by default using the current directory as the include path with no defined macros. These settings can be modified using the flags `--cpp-include` and `--cpp-define`. To disable the C preprocessor use the flag `-XNoCPP`. There are a number of limitations to the C preprocessor support:

* HLint will only check one branch of an `#if`, based on which macros have been defined.
* Any missing `#include` files will produce a warning on the console, but no information in the reports.

### Unicode support

By default, HLint uses the current locale encoding. The encoding can be overridden with either `--utf8` or `--encoding=value`. For descriptions of some valid [encodings see the mkTextEncoding documentation](http://haskell.org/ghc/docs/latest/html/libraries/base/System-IO.html#v%3AmkTextEncoding).

## FAQ

### Why are suggestions not applied recursively?

Consider:

    foo xs = concat (map op xs)

This will suggest eta reduction to `concat . map op`, and then after making that change and running HLint again, will suggest use of `concatMap`. Many people wonder why HLint doesn't directly suggest `concatMap op`. There are a number of reasons:

* HLint aims to both improve code, and to teach the author better style. Doing modifications individually helps this process.
* Sometimes the steps are reasonably complex, by automatically composing them the user may become confused.
* Sometimes HLint gets transformations wrong. If suggestions are applied recursively, one error will cascade.
* Some people only make use of some of the suggestions. In the above example using concatMap is a good idea, but sometimes eta reduction isn't. By suggesting them separately, people can pick and choose.
* Sometimes a transformed expression will be large, and a further hint will apply to some small part of the result, which appears confusing.
* Consider `f $ (a b)`. There are two valid hints, either remove the $ or remove the brackets, but only one can be applied.

### Why aren't the suggestions automatically applied?

If you want to automatically apply suggestions, the [Emacs integration](https://rawgithub.com/ndmitchell/hlint/master/hlint.htm#emacs) offers such a feature. However, there are a number of reasons that HLint itself doesn't have an option to automatically apply suggestions:

* The underlying Haskell parser library makes it hard to modify the code, then print it similarly to the original.
* Sometimes multiple transformations may apply.
* After applying one transformation, others that were otherwise suggested may become inappropriate.

I am intending to develop such a feature, but the above reasons mean it is likely to take some time.

### Why doesn't the compiler automatically apply the optimisations?

HLint doesn't suggest optimisations, it suggests code improvements - the intention is to make the code simpler, rather than making the code perform faster. The [GHC compiler](http://haskell.org/ghc/) automatically applies many of the rules suggested by HLint, so HLint suggestions will rarely improve performance.

### Why doesn't HLint know the fixity for my custom !@%$ operator?

HLint knows the fixities for all the operators in the base library, but no others. HLint works on a single file at a time, and does not resolve imports, so cannot see fixity declarations from imported modules. You can tell HLint about fixities by putting them in a hint file, or passing them on the command line. For example, pass `--with=infixr 5 !@%$`, or put all the fixity declarations in a file and pass `--hint=fixities.hs`. You can also use [--find](https://rawgithub.com/ndmitchell/hlint/master/hlint.htm#find) to automatically produce a list of fixity declarations in a file.

### How can I use `--with` or `--hint` with the default hints?

HLint does not use the default set of hints if custom hints are specified on the command line using `--with` or `--hint`. To include the default hints either pass `--hint=HLint` on the command line, or add import `"hint" HLint.HLint` in one of the hint files you specify with `--hint`.

### Why do I sometimes get a "Note" with my hint?

Most hints are perfect substitutions, and these are displayed without any notes. However, some hints change the semantics of your program - typically in irrelevant ways - but HLint shows a warning note. HLint does not warn when assuming typeclass laws (such as `==` being symmetric). Some notes you may see include:

* __Increases laziness__ - for example `foldl (&&) True` suggests `and` including this note. The new code will work on infinite lists, while the old code would not. Increasing laziness is usually a good idea.
* __Decreases laziness__ - for example `(fst a, snd a)` suggests a including this note. On evaluation the new code will raise an error if a is an error, while the old code would produce a pair containing two error values. Only a small number of hints decrease laziness, and anyone relying on the laziness of the original code would be advised to include a comment.
* __Removes error__ - for example foldr1 (&&) suggests and including the note "Removes error on []". The new code will produce `True` on the empty list, while the old code would raise an error. Unless you are relying on the exception thrown by the empty list, this hint is safe - and if you do rely on the exception, you would be advised to add a comment. 

### What is the difference between error and warning?

Every hint has a severity level:

* __Error__ - for example `concat (map f x)` suggests `concatMap f x` as an "error" severity hint. From a style point of view, you should always replace a combination of `concat` and `map` with `concatMap`. Note that both expressions are equivalent - HLint is reporting an error in style, not an actual error in the code.
* __Warning__ - for example `x !! 0` suggests head x as a "warning" severity hint. Typically head is a simpler way of expressing the first element of a list, especially if you are treating the list inductively. However, in the expression `f (x !! 4) (x !! 0) (x !! 7)`, replacing the middle argument with `head` makes it harder to follow the pattern, and is probably a bad idea. Warning hints are often worthwhile, but should not be applied blindly.

The difference between error and warning is one of personal taste, typically my personal taste. If you already have a well developed sense of Haskell style, you should ignore the difference. If you are a beginner Haskell programmer you may wish to focus on error hints before warning hints.

## Customizing the hints

Many of the hints that are applied by HLint are contained in Haskell source files which are installed in the data directory by Cabal. These files may be edited, to add library specific knowledge, to include hints that may have been missed, or to ignore unwanted hints.

### Choosing a package of hints

By default, HLint will use the `HLint.hs` file either from the current working directory, or from the data directory. Alternatively, hint files can be specified with the `--hint` flag. HLint comes with a number of hint packages:

* __Default__ - these are the hints that are used by default, covering most of the base libraries.
* __Dollar__ - suggests the replacement `a $ b $ c` with `a . b $ c`. This hint is especially popular on the [\#haskell IRC channel](http://www.haskell.org/haskellwiki/IRC_channel).
* __Generalise__ - suggests replacing specific variants of functions (i.e. `map`) with more generic functions (i.e. `fmap`).

As an example, to check the file `Example.hs` with both the default hints and the dollar hint, I could type: `hlint Example.hs --hint=Default --hint=Dollar`. Alternatively, I could create the file `HLint.hs` in the working directory and give it the contents:

    import "hint" HLint.Default
    import "hint" HLint.Dollar

### Ignoring hints

Some of the hints are subjective, and some users believe they should be ignored. Some hints are applicable usually, but occasionally don't always make sense. The ignoring mechanism provides features for suppressing certain hints. Ignore directives can either be written as pragmas in the file being analysed, or in the hint files. Examples of pragmas are:

* `{-# ANN module "HLint: ignore Eta reduce" #-}` - ignore all eta reduction suggestions in this module (use `module` literally, not the name of the module).
* `{-# ANN myFunction "HLint: ignore" #-}` - don't give any hints in the function `myFunction`.
* `{-# ANN myFunction "HLint: error" #-}` - any hint in the function `myFunction` is an error.
* `{-# ANN module "HLint: error Use concatMap" #-}` - the hint to use concatMap is an error.
* `{-# ANN module "HLint: warn Use concatMap" #-}` - the hint to use concatMap is a warning.

Ignore directives can also be written in the hint files:

* `ignore "Eta reduce"` - suppress all eta reduction suggestions.
* `ignore "Eta reduce" = MyModule1 MyModule2` - suppress eta reduction hints in the `MyModule1` and `MyModule2` modules.
* `ignore = MyModule.myFunction` - don't give any hints in the function `MyModule.myFunction`.
* `error = MyModule.myFunction` - any hint in the function `MyModule.myFunction` is an error.
* `error "Use concatMap"` - the hint to use `concatMap` is an error.
* `warn "Use concatMap"` - the hint to use `concatMap` is a warning.

These directives are applied in the order they are given, with later hints overriding earlier ones.

### Adding hints

The hint suggesting `concatMap` is defined as:

    error = concat (map f x) ==> concatMap f x

The line can be read as replace `concat (map f x)` with `concatMap f x`. All single-letter variables are treated as substitution parameters. For examples of more complex hints see the supplied hints file. In general, hints should not be given in point free style, as this reduces the power of the matching. Hints may start with `error` or `warn` to denote how severe they are by default. If you come up with interesting hints, please submit them for inclusion.

You can search for possible hints to add from a source file with the `--find` flag, for example:

    $ hlint --find=src/Utils.hs
    -- hints found in src/Util.hs
    warn = null (intersect a b) ==> disjoint a b
    warn = dropWhile isSpace ==> trimStart
    infixr 5 !:

These hints are suitable for inclusion in a custom hint file. You can also include Haskell fixity declarations in a hint file, and these will also be extracted. If you pass only `--find` flags then the hints will be written out, if you also pass files/folders to check, then the found hints will be automatically used when checking.
