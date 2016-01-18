# Ferret

## Intro

Ferret is an experimental Lisp to C++ compiler, the idea was to
compile code that is written in a very small subset of Clojure to be
automatically translated to C++ so that I can program stuff in
Clojure where JVM or any other Lisp dialect is not available.

This is a literate program, the code in this document is the
executable source, in order to extract it, open the org file
with emacs and run /M-x org-babel-tangle/.
It will build the necessary directory structure and export the files
and tests contained.

## Building

Ferret compiler compiles from Clojure to C++, and then invokes the GNU
C++ compiler to produce binaries. In order to compile a program either
run `lein run -in prog.clj` or if you are using the jar version `java
-jar ferret-app.jar -in sample.clj`. Output will be placed in a a file
called `solution.cpp` passing the `-c` flag will cause this file to be
automatically compiled.
