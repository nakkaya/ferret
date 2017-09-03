DIR = $(shell pwd)
MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)

DOCKER_RUN = docker run --rm -i -t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build
LEIN = cd src/ && lein

test-with-gcc:   CXX = /usr/bin/g++
test-with-clang: CXX = /usr/bin/clang++-4.0

CPPWARNINGS = -pedantic -Werror -Wall -Wextra                    \
              -Wconversion -Wpointer-arith -Wmissing-braces      \
              -Woverloaded-virtual -Wuninitialized -Winit-self
CPPFLAGS = -std=c++11 ${CPPWARNINGS} -pthread

test: CPPSANITIZER = -fsanitize=undefined,address -fno-omit-frame-pointer

.PHONY: test-with-gcc test-with-clang test-compiler test test-ci packr deb deb-repo docs release docker-release clean
.PRECIOUS: %.cpp %.gcc %.clang

src/src/ferret/core.clj: ferret.org
	emacs -nw -Q --batch --eval "(progn (require 'org) (setq org-babel-use-quick-and-dirty-noweb-expansion t) (require 'ob) (find-file \"ferret.org\") (org-babel-tangle))"

bin/ferret : src/src/ferret/core.clj
	mkdir -p bin/
	${LEIN} uberjar
	cat src/resources/jar-sh-header src/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv src/target/ferret.jar bin/ferret.jar

%.cpp: %.clj
	bin/ferret -i $<
	cppcheck --quiet --std=c++11 --template=gcc --enable=all --error-exitcode=1 $@

%.gcc: %.cpp
	$(CXX) $(CPPFLAGS) $(CPPSANITIZER) -x c++ $< -o $@
	$@ 1 2

test-with-gcc: bin/ferret                                \
               src/test/simple_module_main.gcc           \
	       src/test/import_module_main.gcc           \
	       src/test/import_module_empty_aux_a.gcc    \
	       src/test/import_module_empty_aux_b.gcc    \
	       src/test/memory_pool.gcc                  \
	       src/test/runtime_all.gcc

%.clang: %.cpp
	$(CXX) $(CPPFLAGS) $(CPPSANITIZER) -x c++ $< -o $@
	$@ 1 2

test-with-clang: bin/ferret                                \
                 src/test/simple_module_main.clang         \
	         src/test/import_module_main.clang         \
	         src/test/import_module_empty_aux_a.clang  \
	         src/test/import_module_empty_aux_b.clang  \
	         src/test/memory_pool.clang                \
	         src/test/runtime_all.clang

test-compiler: src/src/ferret/core.clj
	${LEIN} test

test:     test-compiler test-with-gcc test-with-clang
test-ci:  test-compiler test-with-gcc test-with-clang

packr:  
	cd src/ && bash resources/build-bundles
	mv src/*.zip bin/
deb:  
	mkdir -p deb/usr/bin
	cp bin/ferret deb/usr/bin/
	mkdir -p deb/DEBIAN
	cp src/resources/deb-package-conf deb/DEBIAN/control
	echo "Version: ${MAJOR_VERSION}.${MINOR_VERSION}" >> deb/DEBIAN/control
	dpkg -b deb ferret-lisp.deb
	rm -rf deb
	mv ferret-lisp.deb bin/
deb-repo: deb
	mkdir -p bin/debian-repo/conf/
	cp src/resources/deb-repo-conf bin/debian-repo/conf/distributions
	reprepro -b bin/debian-repo/ includedeb ferret-lisp bin/ferret-lisp.deb
docs:
	wget https://s3.amazonaws.com/ferret-lang.org/build-artifacts/org-mode-assets.zip
	unzip org-mode-assets.zip
	emacs -nw -Q --batch -l src/resources/tangle-docs
	mkdir -p docs/
	mv ferret-manual.html docs/
	rm org-mode-assets.zip
	mv org-mode-assets docs/ferret-styles
release: clean test-ci packr deb-repo docs
	mkdir -p release/builds/
	mv bin/ferret* release/builds/
	cp release/builds/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv bin/debian-repo release/
	mv docs/* release/
	mv release/ferret-manual.html release/index.html
	rm -rf bin/ docs/
docker-release:
	 ${DOCKER_RUN} /bin/bash -c 'make release'
clean:
	rm -rf src/ bin/ docs/ org-mode-assets* release/
