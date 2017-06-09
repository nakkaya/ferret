# Ferret

[![Current Release][badge-ferret-version]][ferret-downloads]
[![CI Build Status][badge-ferret-build]][ferret-travis]

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

    wget http://ferret-lang.org/builds/ferret.jar
    
A program that sums the first 5 positive numbers. 

    ;;; lazy-sum.clj
    (defn positive-numbers
      ([]
       (positive-numbers 1))
      ([n]
       (cons n (lazy-seq (positive-numbers (inc n))))))

    (println (->> (positive-numbers)
                  (take 5)
                  (apply +)))
                  
Compile to binary using,

    $ java -jar ferret.jar -i lazy-sum.clj
    $ g++ -std=c++11 -pthread lazy-sum.cpp
    $ ./a.out

## License

BSD 2-Clause License

Copyright (c) 2017, Nurullah Akkaya
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[ferret-travis]: https://travis-ci.org/nakkaya/ferret/builds
[ferret-downloads]: http://ferret-lang.org
[badge-ferret-version]: https://badge.fury.io/gh/nakkaya%2Fferret.svg
[badge-ferret-build]: https://travis-ci.org/nakkaya/ferret.svg?branch=master

