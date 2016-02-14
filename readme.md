# Ferret

Ferret is a Clojure to C++ compiler, projects aim is to create a
functional minimum viable lisp that runs on embedded systems with
deterministic behaviour by compiling a subset of Clojure to C++.

Generated code is self contained ANSI C++98 with no third part
dependencies including `libstdc++`. Which allows it to run on embedded
systems with as little as 2KB of RAM and no `libstdc++`. (Arduino Uno
/ Atmega328 with 32kb Flash)

Ferret is not trying to be a 1 to 1 Clojure to C++ compiler. Projects
eventual aim is to create Clojure flavored lisp with ideas from Ada
that makes it suitable for embedded programming.

## Features

 - Very small foot print.
 - Functional
 - Macros
 - Destructuring
 - Easy FFI (Inline C,C++)
 - Memory Pooling

## Implementation Notes

Ferret is a functional language. All functions should mimic their
Clojure counter parts. If they don't  it is considered a bug. (or not
possible to implement with the current implementation.)

The code it produces does not include any black magic it is simple
C++. All tests are compiled using,

 - `-std=c++98`
 - `-ansi`
 - `-pedantic`
 - `-Werror`
 - `-Wall`
 - `-Wextra`
 - `-Woverloaded-virtual`
 - `-Wuninitialized`
 - `-Wmissing-declarations`
 - `-Winit-self`
 - `-Wno-variadic-macros`

## Object System

All objects derive from `Object` class.

 - `Pointer` - For Holding references to native objects.
 - `Number` - All numbers are kept as ratios (two ints).
 - `Keyword` 
 - `Character`
 - `Sequence`
 - `LazySequence`
 - `String`
 - `Boolean`
 - `Atom` - Mimics Clojure atoms.
 - `Lambda`

Memory management is done using reference counting. On memory
constraint systems such as micro controllers ferret can use a memory
pool to avoid heap fragmentation and calling `malloc` / `free`.

    (configure! MEMORY_POOL_SIZE 256)

This will create a pool object as a global variable that holds an
array of `256 * size_t`. Memory pooling is intended for embedded systems
where calling `malloc`/`free` is not desired. It is not thread safe It
should not be used in systems where better alternatives exists or you
have enough memory.

## Compiling With Ferret

Compile `prog.clj`,

    lein run -in prog.clj

or if you are using the jar version,

    java -jar ferret-app.jar -in prog.clj

Output will be placed in a a file called `solution.cpp` passing the
`-c` flag will cause this file to be automatically compiled using GNU
C++. (Other compilers are supprted see Implementation Notes).


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

In addition to `defn` form there is also a `defnative` form which
allows you to define different function bodies for different `#define`
directives,

    (defnative get-char []
      (on "defined GNU_GCC"
          "__result = NEW_CHARACTER(getchar());"))

This function when compiled on a system that defines `GNU_GCC` will
return the result of `getchar` as a `Character` on ANY other system it
will return `nil`. You can have multiple `on` blocks per `defnative`,

    (defnative sleep [timeout]
      (on "defined GNU_GCC"
          ("unistd.h")
          "::sleep(TO_INT(timeout));")
      (on "defined AVR_GCC"
          "::delay(TO_INT(timeout));"))

This way single function can be defined for multiple systems.

## Embedded Usage

If you can use a C++ compiler for your embedded platform, you can use
ferret. Following shows a blink example for Arduino.

    (pin-mode 13 :output)
  
    (forever
     (digital-write 13 :high)
     (sleep 500)
     (digital-write 13 :low)
     (sleep 500))

Rename `solution.cpp` to `./program_name/program_name.pde` and compile
using Arduino IDE.

If you are using the memory pool, there are two functions you can use
to check on memory,

 - `memory-pool-free-pages` - Returns the number of free memory pages.
 - `memory-pool-print-snapshot` - Prints the current state of
    memory. Each block is  denoted as 0(free) or 1(used).

## Wrapping Third Party C,C++ Libraries

### [ferret-serial](https://git.nakkaya.com/nakkaya/ferret-serial)

Boost Asio Serial Port Wrapper For Ferret.

### [ferret-firmata](https://git.nakkaya.com/nakkaya/ferret-firmata)

Firmata protocol implementation that uses `ferret-serial` and `stl`.

## License

Copyright 2015 Nurullah Akkaya

This file is part of Ferret.

Ferret is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version. 

Ferret is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details. 

You should have received a copy of the GNU General Public License
along with Foobar. If not, see http://www.gnu.org/licenses/.
