<h1>

Ferret 
[![Badge License]][License] 
[![Badge Version]][Website] 
[![Badge Build]][Travis]

</h1>

Ferret is a free software lisp implementation designed to be used in
real time embedded control systems. Ferret lisp compiles down to self
contained *C++11*. Generated code is portable between any Operating
System and/or Microcontroller that supports a *C++11* compliant
compiler. It has been verified to run on architectures ranging from
embedded systems with as little as *2KB of RAM* to general purpose
computers running Linux/Mac OS X/Windows.

This repository contains the Ferret compiler. For more information about Ferret, 
including downloads and documentation for the latest release, check 
out [Ferret's website][Website]

## General Information

   - [Website]
   - [Source Code]
   - [Mailing List]
   - [Issue Tracker]

## Quick Start

Download latest Ferret release,

```bash
wget https://ferret-lang.org/builds/ferret.jar
```

A program that sums the first 5 positive numbers. 

```clojure
;;; lazy-sum.clj
(defn positive-numbers
  ([]
   (positive-numbers 1))
  ([n]
   (cons n (lazy-seq (positive-numbers (inc n))))))

(println (->> (positive-numbers)
              (take 5)
              (apply +)))
```

Compile to binary using,

```bash
$ java -jar ferret.jar -i lazy-sum.clj
$ g++ -std=c++11 -pthread lazy-sum.cpp
$ ./a.out
```

<!----------------------------------------------------------------------------->

[Badge Version]: https://badge.fury.io/gh/nakkaya%2Fferret.svg
[Badge Build]: https://travis-ci.org/nakkaya/ferret.svg?branch=master
[Badge License]: https://img.shields.io/badge/License-BSD%202--Clause-orange.svg

[Issue Tracker]: https://github.com/nakkaya/ferret/issues
[Mailing List]: https://groups.google.com/forum/#!forum/ferret-lang
[Source Code]: https://github.com/nakkaya/ferret
[Website]: https://ferret-lang.org
[Travis]: https://travis-ci.org/nakkaya/ferret/builds 'CI Build Status'

[License]: LICENSE
