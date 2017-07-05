# Ferret

[![Current Release][badge-ferret-version]][ferret-downloads]
[![CI Build Status][badge-ferret-build]][ferret-travis]
![BSD 2 Clause License][badge-ferret-license]

Ferret is a free software Clojure implementation, it compiles a restricted subset of the 
Clojure language to self contained ISO C++11 which allows for the use of 
Clojure in real time embedded control systems. 

This repository contains the Ferret compiler. For more information about Ferret, 
including downloads and documentation for the latest release, check 
out [Ferret's website](http://ferret-lang.org)

## General Information

   - Website - http://ferret-lang.org
   - Source Code - https://github.com/nakkaya/ferret - https://git.nakkaya.com/nakkaya/ferret
   - Mailing List - https://groups.google.com/forum/#!forum/ferret-lang
   - Issue Tracker - https://github.com/nakkaya/ferret/issues

## Quick Start

Download latest Ferret release,

```bash
wget http://ferret-lang.org/builds/ferret.jar
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
[ferret-downloads]: http://ferret-lang.org
[badge-ferret-version]: https://badge.fury.io/gh/nakkaya%2Fferret.svg
[badge-ferret-build]: https://travis-ci.org/nakkaya/ferret.svg?branch=master
[badge-ferret-license]: https://img.shields.io/badge/License-BSD%202--Clause-orange.svg
