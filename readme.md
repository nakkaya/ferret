# Ferret

[![Current Release][badge-ferret-version]][ferret-downloads]
[![CI Build Status][badge-ferret-build]][ferret-travis]
![BSD 2 Clause License][badge-ferret-license]

Ferret is a free software lisp implementation designed to be used in
real time embedded control systems. Ferret lisp compiles down to self
contained *C++11*. Generated code is portable between any Operating
System and/or Microcontroller that supports a *C++11* compliant
compiler. It has been verified to run on architectures ranging from
embedded systems with as little as *2KB of RAM* to general purpose
computers running Linux/Mac OS X/Windows.

This repository contains the Ferret compiler. For more information about Ferret, 
including downloads and documentation for the latest release, check 
out [Ferret's website](https://ferret-lang.org)

## General Information

   - Website - https://ferret-lang.org
   - Source Code - https://github.com/nakkaya/ferret
   - Mailing List - https://groups.google.com/forum/#!forum/ferret-lang
   - Issue Tracker - https://github.com/nakkaya/ferret/issues

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

[ferret-travis]: https://travis-ci.org/nakkaya/ferret/builds
[ferret-downloads]: https://ferret-lang.org
[badge-ferret-version]: https://badge.fury.io/gh/nakkaya%2Fferret.svg
[badge-ferret-build]: https://travis-ci.org/nakkaya/ferret.svg?branch=master
[badge-ferret-license]: https://img.shields.io/badge/License-BSD%202--Clause-orange.svg
