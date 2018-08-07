DIR = $(shell pwd)
MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)
VERSION = ${MAJOR_VERSION}.${MINOR_VERSION}

.DEFAULT_GOAL := bin/ferret
.PHONY: test test-release deb deb-repo docs release docker-release clean
.PRECIOUS: %.cpp %.gcc %.clang %.ino

clean:
	rm -rf src/ bin/ docs/ release/

# tangle compiler generate src/ directory
src/: ferret.org
	emacs -nw -Q --batch --eval "(progn (require 'org) (setq org-babel-use-quick-and-dirty-noweb-expansion t) (require 'ob) (setq org-confirm-babel-evaluate nil) (org-babel-do-load-languages 'org-babel-load-languages '((sh . t))) (find-file \"ferret.org\") (org-babel-tangle))"

# run low level unit tests and generate bin/ferret
bin/ferret : src/
	mkdir -p bin/
	cd src/ && lein uberjar
	cat src/resources/jar-sh-header src/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv src/target/ferret.jar bin/ferret.jar

# tell make how to compile Ferret lisp to C++
%.cpp: %.clj
	bin/ferret -i $<

# each compiler/framework to be tested get an extensiton. 
# i.e all cpp files compiled with g++ will have .gcc extension

CPPWARNINGS = -pedantic -Werror -Wall -Wextra                        \
              -Wconversion -Wpointer-arith -Wmissing-braces          \
              -Woverloaded-virtual -Wuninitialized -Winit-self       \
	      -Wsign-conversion

CPPFLAGS = -std=c++11 -fno-rtti ${CPPWARNINGS} -pthread -I src/src/ferret/

define static_check
    cppcheck --quiet --language=c++ --std=c++11 --template=gcc --enable=all --error-exitcode=1 $1 2> "$1.cppcheck"
endef

# only enable sanitizers when running in docker
test-release: CPPFLAGS += -fsanitize=undefined,address,leak -fno-omit-frame-pointer

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
NATIVE_TESTS = src/test/native/fixed_real.cpp                  \
               src/test/native/euclidean_vector.cpp            \
               src/test/native/container_array.cpp             \
               src/test/native/memory_pool.cpp

CORE_TESTS = src/test/core/module.clj                     \
	     src/test/core/module_unit_test.clj           \
             src/test/core/module_import_empty_aux_a.clj  \
             src/test/core/module_import_empty_aux_b.clj  \
             src/test/core/allocator_api.clj              \
             src/test/core/core.clj                       \
             src/test/core/net/multicast.clj              \
             src/test/core/concurrency.clj

EMBEDDED_TESTS = src/test/embedded/blink/blink.clj              \
	         src/test/embedded/blink-multi/blink-multi.clj  \
	         src/test/embedded/interrupt/interrupt.clj

# assign tests to compilers
CLANG_OBJS = $(NATIVE_TESTS:.cpp=.clang)   $(CORE_TESTS:.clj=.clang)
GCC_OBJS   = $(NATIVE_TESTS:.cpp=.gcc)     $(CORE_TESTS:.clj=.gcc)
CXX_OBJS   = $(NATIVE_TESTS:.cpp=.cxx)     $(CORE_TESTS:.clj=.cxx)
INO_OBJS   = $(EMBEDDED_TESTS:.clj=.ino)

test-compiler:
	cd src/ && lein test
test: bin/ferret test-compiler $(CXX_OBJS)
test-release: bin/ferret test-compiler $(GCC_OBJS) $(CLANG_OBJS) $(INO_OBJS)

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
clojars: 
	cd src/ && lein deploy
docs:   src/
	wget https://s3.amazonaws.com/ferret-lang.org/build-artifacts/clojure-mode-extra-font-locking.el
	emacs -nw -Q --batch -l src/resources/tangle-docs
	mkdir -p docs/
	mv ferret-manual.html docs/
	rm clojure-mode-extra-font-locking.el
release: clean test-release clojars deb-repo docs
	mkdir -p release/builds/
	mv bin/ferret* release/builds/
	cp release/builds/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv bin/debian-repo release/
	mv docs/ferret-manual.html release/index.html
	rm -rf bin/ docs/

# rules for managing the docker files used by the CI
DOCKER_RUN = docker run --rm -i \
		-e LEIN_JVM_OPTS='-Dhttps.protocols=TLSv1.2' \
		-e LEIN_PASSWORD='${LEIN_USERNAME}' \
		-e LEIN_PASSWORD='${LEIN_PASSWORD}' \
		-t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build

docker-create: src/
	cd src/resources/ferret-build/ && \
	   sudo docker build -t nakkaya/ferret-build:latest -t nakkaya/ferret-build:${VERSION} .
	sudo docker push nakkaya/ferret-build:${VERSION}
	sudo docker push nakkaya/ferret-build:latest
docker-bash:
	 ${DOCKER_RUN} /bin/bash
docker-release:
	 @${DOCKER_RUN} /bin/bash -c 'make release'
docker-test:
	 ${DOCKER_RUN} /bin/bash -c 'make test-release'
