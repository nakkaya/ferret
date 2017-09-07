DIR = $(shell pwd)
MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)
VERSION = ${MAJOR_VERSION}.${MINOR_VERSION}

.PHONY: test test-release deb deb-repo docs release docker-release clean
.PRECIOUS: %.cpp %.gcc %.clang %.ino

clean:
	rm -rf src/ bin/ docs/ release/

# tangle compiler generate src/ directory
src/src/ferret/core.clj: ferret.org
	emacs -nw -Q --batch --eval "(progn (require 'org) (setq org-babel-use-quick-and-dirty-noweb-expansion t) (require 'ob) (find-file \"ferret.org\") (org-babel-tangle))"

# run low level unit tests and generate bin/ferret
bin/ferret : src/src/ferret/core.clj
	mkdir -p bin/
	cd src/ && lein test
	cd src/ && lein uberjar
	cat src/resources/jar-sh-header src/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv src/target/ferret.jar bin/ferret.jar

# tell make how to compile Ferret lisp to C++
%.cpp: %.clj
	bin/ferret -i $<

# each compiler/framework to be tested get an extensiton. 
# i.e all cpp files compiled with g++ will have .gcc extension

CPPWARNINGS = -pedantic -Werror -Wall -Wextra                    \
              -Wconversion -Wpointer-arith -Wmissing-braces      \
              -Woverloaded-virtual -Wuninitialized -Winit-self
CPPFLAGS = -std=c++11 -fno-rtti ${CPPWARNINGS} -pthread -I src/src/ferret/

define static_check
    cppcheck --quiet --std=c++11 --template=gcc --enable=all --error-exitcode=1 $1 2> "$1.cppcheck"
endef

# only enable sanitizers when not running in docker
test: CPPFLAGS += -fsanitize=undefined,address -fno-omit-frame-pointer

%.gcc: %.cpp
	g++ $(CPPFLAGS) -x c++ $< -o $@
	$(call static_check,$<)
	$@ 1 2

%.clang: %.cpp
	clang++ $(CPPFLAGS) -x c++ $< -o $@
	$(call static_check,$<)
	$@ 1 2

%.cxx: %.cpp
	$(CXX) $(CPPFLAGS) -x c++ $< -o $@
	$(call static_check,$<)
	$@ 1 2

%.ino: %.cpp
	mv $< $@
	$(call static_check,$@)
	arduino --verify --board arduino:avr:uno $@

# list of unit tests to run againts the current build
NATIVE_TESTS = src/test/fixed_real.cpp

STD_LIB_TESTS = src/test/simple_module_main.clj         \
                src/test/import_module_main.clj         \
                src/test/import_module_empty_aux_a.clj  \
                src/test/import_module_empty_aux_b.clj  \
                src/test/memory_pool.clj                \
                src/test/runtime_all.clj

EMBEDDED_TESTS = src/test/blink/blink.clj              \
	         src/test/blink-multi/blink-multi.clj

# assign tests to compilers
CLANG_OBJS = $(NATIVE_TESTS:.cpp=.clang)   $(STD_LIB_TESTS:.clj=.clang)
GCC_OBJS   = $(NATIVE_TESTS:.cpp=.gcc)     $(STD_LIB_TESTS:.clj=.gcc)
CXX_OBJS   = $(NATIVE_TESTS:.cpp=.cxx)     $(STD_LIB_TESTS:.clj=.cxx)
INO_OBJS   = $(EMBEDDED_TESTS:.clj=.ino)

test: bin/ferret $(CXX_OBJS)
test-release: bin/ferret $(GCC_OBJS) $(CLANG_OBJS) $(INO_OBJS)

# rules for preparing a release
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
release: clean test-release deb-repo docs
	mkdir -p release/builds/
	mv bin/ferret* release/builds/
	cp release/builds/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv bin/debian-repo release/
	mv docs/ferret-manual.html release/index.html
	rm -rf bin/ docs/

# rules for managing the docker files used by the CI
DOCKER_RUN = docker run --rm -i -t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build

docker-create: src/src/ferret/core.clj
	cd src/resources/ferret-build/ && \
	   sudo docker build -t nakkaya/ferret-build:latest -t nakkaya/ferret-build:${VERSION} .
	sudo docker push nakkaya/ferret-build:${VERSION}
	sudo docker push nakkaya/ferret-build:latest
docker-release:
	 ${DOCKER_RUN} /bin/bash -c 'make release'
docker-test:
	 ${DOCKER_RUN} /bin/bash -c 'make test-release'
