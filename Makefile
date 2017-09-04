DIR = $(shell pwd)
MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)
VERSION = ${MAJOR_VERSION}.${MINOR_VERSION}

DOCKER_RUN = docker run --rm -i -t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build
LEIN = cd src/ && lein

CPPWARNINGS = -pedantic -Werror -Wall -Wextra                    \
              -Wconversion -Wpointer-arith -Wmissing-braces      \
              -Woverloaded-virtual -Wuninitialized -Winit-self
CPPFLAGS = -std=c++11 ${CPPWARNINGS} -pthread

test: CPPSANITIZER = -fsanitize=undefined,address -fno-omit-frame-pointer

.PHONY: test test-release packr deb deb-repo docs release docker-release clean
.PRECIOUS: %.cpp %.gcc %.clang %.ino

src/src/ferret/core.clj: ferret.org
	emacs -nw -Q --batch --eval "(progn (require 'org) (setq org-babel-use-quick-and-dirty-noweb-expansion t) (require 'ob) (find-file \"ferret.org\") (org-babel-tangle))"

bin/ferret : src/src/ferret/core.clj
	mkdir -p bin/
	${LEIN} test
	${LEIN} uberjar
	cat src/resources/jar-sh-header src/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv src/target/ferret.jar bin/ferret.jar

%.cpp: %.clj
	bin/ferret -i $<
	cppcheck --quiet --std=c++11 --template=gcc --enable=all --error-exitcode=1 $@

%.gcc: %.cpp
	/usr/bin/g++ $(CPPFLAGS) $(CPPSANITIZER) -x c++ $< -o $@
	$@ 1 2

%.clang: %.cpp
	/usr/bin/clang++ $(CPPFLAGS) $(CPPSANITIZER) -x c++ $< -o $@
	$@ 1 2

%.cxx: %.cpp
	$(CXX) $(CPPFLAGS) $(CPPSANITIZER) -x c++ $< -o $@
	$@ 1 2

%.ino: %.cpp
	mv $< $@
	arduino --verify --board arduino:avr:uno $@

STD_LIB_TESTS = src/test/simple_module_main.clj         \
                src/test/import_module_main.clj         \
                src/test/import_module_empty_aux_a.clj  \
                src/test/import_module_empty_aux_b.clj  \
                src/test/memory_pool.clj                \
                src/test/runtime_all.clj

CLANG_OBJS=$(STD_LIB_TESTS:.clj=.clang)
GCC_OBJS=$(STD_LIB_TESTS:.clj=.gcc)
CXX_OBJS=$(STD_LIB_TESTS:.clj=.cxx)

EMBEDDED_TESTS = src/test/blink/blink.clj              \
	         src/test/blink-multi/blink-multi.clj

INO_OBJS=$(EMBEDDED_TESTS:.clj=.ino)

test: bin/ferret $(CXX_OBJS)
test-release: bin/ferret $(GCC_OBJS) $(CLANG_OBJS) $(INO_OBJS)

packr:  bin/ferret
	bash src/resources/build-bundles
	mv *.zip bin/
deb:    bin/ferret
	mkdir -p deb/usr/bin
	cp bin/ferret deb/usr/bin/
	mkdir -p deb/DEBIAN
	cp src/resources/deb-package-conf deb/DEBIAN/control
	echo "Version: ${VERSION}" >> deb/DEBIAN/control
	dpkg -b deb ferret-lisp.deb
	rm -rf deb
	mv ferret-lisp.deb bin/
deb-repo: deb
	mkdir -p bin/debian-repo/conf/
	cp src/resources/deb-repo-conf bin/debian-repo/conf/distributions
	reprepro -b bin/debian-repo/ includedeb ferret-lisp bin/ferret-lisp.deb
docs:   src/src/ferret/core.clj
	wget https://s3.amazonaws.com/ferret-lang.org/build-artifacts/clojure-mode-extra-font-locking.el
	emacs -nw -Q --batch -l src/resources/tangle-docs
	mkdir -p docs/
	mv ferret-manual.html docs/
	rm clojure-mode-extra-font-locking.el
release: clean test-release packr deb-repo docs
	mkdir -p release/builds/
	mv bin/ferret* release/builds/
	cp release/builds/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv bin/debian-repo release/
	mv docs/ferret-manual.html release/index.html
	rm -rf bin/ docs/

docker-create: src/src/ferret/core.clj
	cd src/resources/ferret-build/ && \
	   sudo docker build -t nakkaya/ferret-build:latest -t nakkaya/ferret-build:${VERSION} .
	sudo docker push nakkaya/ferret-build:${VERSION}
	sudo docker push nakkaya/ferret-build:latest
docker-release:
	 ${DOCKER_RUN} /bin/bash -c 'make release'
docker-test:
	 ${DOCKER_RUN} /bin/bash -c 'make test-release'
clean:
	rm -rf src/ bin/ docs/ org-mode-assets* release/
