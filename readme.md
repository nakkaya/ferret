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

If you can use a C++ compiler for your embedded platform. You can use
ferret for your embedded platform. Following shows a blink example for
Arduino.

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

## Wrapping Third Party C Libraries

### SQLite

Following shows an example of how to interface with SQLite and how to
convert data structures back and forth with ferret and native code.

    (native-header sqlite3.h)
  
    (defn open-db []
      "sqlite3 *db;
       int rc = sqlite3_open(\"./test.db\", &db);
       if (rc == SQLITE_OK)
         __result = NEW_POINTER(db);
       else
        fprintf(stderr, \"Cannot open database: %s\\n\", sqlite3_errmsg(db));")
  
    (defn close-db [db]
      "sqlite3_close(TO_POINTER(db,sqlite3));")
  
    (defn exec-db [db sql]
      "char *err_msg = 0;
       int rc = sqlite3_exec(TO_POINTER(db,sqlite3), TO_C_STR(sql), 0, 0, &err_msg);
       if (rc == SQLITE_OK)
         __result = NEW_BOOLEAN(true);
       else{
         fprintf(stderr, \"SQL error: %s\\n\", err_msg);
         sqlite3_free(err_msg);}")
  
    (defn prep-stmt-db [db-ptr sql]
      "char *err_msg = 0;
       sqlite3_stmt *stmt;
       sqlite3* db = TO_POINTER(db_ptr,sqlite3);
       int rc = sqlite3_prepare_v2(db, TO_C_STR(sql), -1, &stmt, NULL);
       if (rc == SQLITE_OK)
         __result = NEW_POINTER(stmt);
       else{
         fprintf(stderr, \"Cannot open database: %s\\n\", sqlite3_errmsg(db));
         sqlite3_finalize(stmt);
         sqlite3_free(err_msg);}")
  
    (defn select-db [stmt-ptr]
      "sqlite3_stmt *stmt = TO_POINTER(stmt_ptr,sqlite3_stmt);
       __result = NEW_SEQUENCE();
       while(sqlite3_step(stmt) == SQLITE_ROW){
         const char* col = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
         CONS(__result,NEW_STRING(col));
       }
       sqlite3_finalize(stmt);")

Assuming above file is saved as `utils.db.clj`. It can be imported
from other ferret programs using,

    (require '[utils.db :as db])

Functions in the file can be using using `:as` prefix. `select-db`
becomes `db/select-db`

    (require '[utils.db :as db])
    (def setup-db (list "DROP TABLE IF EXISTS Cars;" 
                        "CREATE TABLE Cars(Id INT, Name TEXT, Price INT);" 
                        "INSERT INTO Cars VALUES(1, 'Audi', 52642);" 
                        "INSERT INTO Cars VALUES(2, 'Mercedes', 57127);" 
                        "INSERT INTO Cars VALUES(3, 'Skoda', 9000);" 
                        "INSERT INTO Cars VALUES(4, 'Volvo', 29000);" 
                        "INSERT INTO Cars VALUES(5, 'Bentley', 350000);" 
                        "INSERT INTO Cars VALUES(6, 'Citroen', 21000);" 
                        "INSERT INTO Cars VALUES(7, 'Hummer', 41400);" 
                        "INSERT INTO Cars VALUES(8, 'Volkswagen', 21600);"))
  
    (def db (db/open-db))
  
    (doseq [sql setup-db]
      (db/exec-db db sql))
  
    (def select-all (db/prep-stmt-db db "SELECT * FROM Cars"))
  
    (println (db/select-db select-all))

When `-c` is used, in order to pass compiler options to the compiler
ferret supports simple build options files. A Clojure map with
settings to override/add.

    {:include-path ["/usr/local/Cellar/sqlite/3.8.2/include/"]
     :library-path ["/usr/local/Cellar/sqlite/3.8.2/lib/"]
     :link ["sqlite3"]
     :compiler-options ["-Wall"]}

Assuming above is saved as `build.options` A program can be compiled
using `-i program.clj -c -o build.options`.

### Mongoose

This example uses Mongoose embedded web server. `defcallback` can be
used to register C Style callbacks when interfacing with C libraries.

Build options,

    {:extra-source-files ["mongoose.c"]}

Program,

    (native-header mongoose.h)
  
    (native-declare "static struct mg_serve_http_opts s_http_server_opts;")
  
    (defn request-listener [nc ev p]
      "if (TO_INT(ev) == MG_EV_HTTP_REQUEST) {
           mg_serve_http(TO_POINTER(nc,struct mg_connection), 
                         TO_POINTER(p,struct http_message), 
                         s_http_server_opts);
         }")
  
    (defcallback request-listener
      "void" "struct mg_connection *nc, int ev, void *p"
      "NEW_POINTER(nc)" "VAR(ev)" "NEW_POINTER(p)")
  
    (defn web-server-init [port]
      "struct mg_mgr *mgr = (struct mg_mgr *)malloc(sizeof(mg_mgr));
       struct mg_connection *nc;
  
       mg_mgr_init(mgr, NULL);
       nc = mg_bind(mgr, TO_C_STR(port), request_listener_callback);
  
       // Set up HTTP server parameters
       mg_set_protocol_http_websocket(nc);
       s_http_server_opts.document_root = \".\";  // Serve current directory
       s_http_server_opts.dav_document_root = \".\";  // Allow access via WebDav
       s_http_server_opts.enable_directory_listing = \"yes\";
       __result = NEW_POINTER(mgr);")
  
    (defn web-server-poll [mgr]
      "mg_mgr_poll(TO_POINTER(mgr,struct mg_mgr), 1000);")
  
    (def server (web-server-init "8000"))
  
    (while true (web-server-poll server))

### OpenCV

Build options,

    {:include-path ["/usr/local/Cellar/opencv/2.4.9/include/"]
     :library-path ["/usr/local/Cellar/opencv/2.4.9/lib/"]
     :link ["opencv_core"
            "opencv_highgui"]
     :compiler-options ["-Wall"]
     :name "cv-webcam"}

Program,

    (native-header "opencv/cv.h"
                   "opencv/highgui.h")
    
    (defn wait-key [i] "__result = var((char)cvWaitKey(NUMBER(i)->intValue()));")
    
    (defn video-capture [i]
      "cv::VideoCapture *cap = new cv::VideoCapture(NUMBER(i)->intValue());
       if (cap->isOpened())
        __result = var(new Pointer(cap));")
    
    (defn named-window [n] "cv::namedWindow(STRING(n)->toString(),1);")
    
    (defn query-frame [c]
      "cv::VideoCapture *cap = static_cast<cv::VideoCapture*>(POINTER(c)->ptr);
       cap->grab();
       cv::Mat *image = new cv::Mat;
       cap->retrieve(*image, 0);
       __result = var(new Pointer(image));")
    
    (defn show-image [f img]
      "cv::Mat *i = static_cast<cv::Mat*>(POINTER(img)->ptr);
       imshow(STRING(f)->toString(), *i);")
    
    (def cam (video-capture 0))
    
    (named-window "cam")
    
    (while (not= (wait-key 1) \q)
      (let [f (query-frame cam)]
        (show-image "cam" f)))

Compile `-i webcam.clj -o build.options`.

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
