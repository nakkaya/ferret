# Ferret

Ferret is an experimental Lisp to C++ compiler, the idea was to
compile code that is written in a very small subset of Clojure to be
automatically translated to C++ so that I can program stuff in Clojure
where JVM or any other Lisp dialect is not available. 

This is a literate program, the code in this document is the
executable source, in order to extract it, open the org file with
emacs and run /M-x org-babel-tangle/. It will build the necessary
directory structure and export the files and tests contained.

## Building

Ferret compiler compiles from a subset of Clojure to C++, and then
invokes the GNU C++ compiler to produce binaries. In order to compile
a program either run,

    lein run -in prog.clj

or if you are using the jar version

    java -jar ferret-app.jar -in sample.clj

Output will be placed in a a file called `solution.cpp` passing the
`-c` flag will cause this file to be automatically compiled.

## Features

 - Very small foot print
 - Functional
 - Macros
 - Destructuring
 - Memory Pooling

## Object System

All objects derive from `Object` class.

 - `Pointer` - For Holding references to native objects.
 - `Number` - All numbers are kept as ratios (two ints).
 - `Keyword` 
 - `Character`
 - `Sequence`
 - `String`
 - `Boolean`
 - `Atom` - Mimics Clojure atoms.
 - `Lambda`

Memory management is done using reference counting. On memory
constraint systems such as micro controllers ferret can use a memory
pool to avoid heap fragmentation and calling `malloc` / `free`.

    (native-define "#define MEMORY_POOL_SIZE 256")

This will create a pool object as a global variable that holds an
array of 256 `size_t`.

## Examples

### Built In

Some built in stuff,

Arithmetic,

    (+ 0.3 0.3)
    (* 2.0 2 2)
    (bit-not  4) ;; -5
    (pos? 0.2)
    (neg? -1)

Comparison,

    (< 2 3 4 5)
    (>= 5 4 3 2 2 2)
    (= 2 2.0 2)

Conditionals,

    (if (zero? 0)
      "Zero" "No Zero")

    (when (zero? 0) "Zero")

Sequences,

    (let [alist (list 1 2 3 4)]
      (println (first alist))
      (println (rest alist))
      (println (count alist)))


    (reduce + (list 1 2 3 4 5 6))
    (apply + (list 1 2 3 4 5 6))
    
Sequence functions use the `ISeekable` interface to iterate there is
also a `defobject` special form that allows user defineable
classes. So you can plug your own objects into ferret ecosystem.


Atoms,

    (let [a (atom nil)]
      (reset! a 1)
      (swap! a inc))

### FFI

You can declare global level things using,

    (native-declare "int i = 0;")

this will define an `int` called `i` as a global variable. If a
function only contains a string such as,

    (defn inc-int [] "__result =  NEW_NUMBER(i++);")

It is assumed to be a native function string it is taken as C++
code. You can then use it like any other ferret function.

    (while (< (inc-int) 10)
      (print 1))

## Embedded Usage

If you can use GNU C++ compiler. You can use ferret for your embedded
platform. Following shows a blink example.

    (pin-mode 13 :output)
  
    (forever
     (digital-write 13 :high)
     (sleep 500)
     (digital-write 13 :low)
     (sleep 500))

Rename `solution.cpp` to `./program_name/program_name.pde`

If you are using the memory pool, there are two functions you can use
to what memory,

 - `memory-pool-free-pages` - Returns the number of free memory pages.
 - `memory-pool-print-snapshot` - Prints the current state of
    memory. Each block is  denoted as 0(free) or 1(used).

## Implementation Notes

Ferret is functional. The code it produces does not include any black
magic it is simple C++. There is only one GCC trick in the code other
than that it should support any compiler.

## License

GNU General Public License
