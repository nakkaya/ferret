
# Usage

### Example

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

<br>

### Compile

Build the binary using:

```bash
java -jar ferret.jar -i lazy-sum.clj
g++ -std=c++11 -pthread lazy-sum.cpp
./a.out
```