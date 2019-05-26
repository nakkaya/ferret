DIR = $(shell pwd)
MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)
VERSION = ${MAJOR_VERSION}.${MINOR_VERSION}

.DEFAULT_GOAL := bin/ferret
.PHONY: clean repl test-compiler test-core test-all test-release deb deb-repo clojars docs release docker-build docker-bash docker-release docker-test
.PRECIOUS: %.cpp %.gcc %.clang %.ino

CPPWARNINGS = -pedantic -Werror -Wall -Wextra                        \
              -Wconversion -Wpointer-arith -Wmissing-braces          \
              -Woverloaded-virtual -Wuninitialized -Winit-self       \
	      -Wsign-conversion -ggdb

CPPFLAGS = -std=c++11 -fno-rtti ${CPPWARNINGS} -pthread -I src/runtime/

# only enable sanitizers during release test
test-release: CPP_SANITIZE_FLAGS += -fsanitize=undefined,address,leak

CPPCHECK_CONF = -DFERRET_STD_LIB

define static_check
    cppcheck --quiet\
    ${CPPCHECK_CONF} \
    --language=c++ --std=c++11 --template=gcc --enable=all\
    --inline-suppr\
    --suppress=preprocessorErrorDirective:$1 \
    --suppress=unusedFunction:$1\
    --suppress=missingIncludeSystem:$1\
    --suppress=unmatchedSuppression:$1\
    --error-exitcode=1 $1 2> "$1.cppcheck"
endef

clean:
	rm -rf resources/ src/ test/ project.clj bin/ docs/ release/ core*

# tangle compiler
project.clj: ferret.org
	emacs -nw -Q --batch --eval \
	"(progn                                                     \
           (require 'org)                                           \
           (require 'ob)                                            \
           (setq org-babel-use-quick-and-dirty-noweb-expansion t)   \
           (setq org-confirm-babel-evaluate nil)                    \
	   (when (locate-library \"ob-sh\")                         \
            (org-babel-do-load-languages                            \
              'org-babel-load-languages '((sh . t))))               \
	   (when (locate-library \"ob-shell\")                      \
            (org-babel-do-load-languages                            \
              'org-babel-load-languages '((shell . t))))            \
           (find-file \"ferret.org\")                               \
           (org-babel-tangle))"

# run low level unit tests and generate bin/ferret
bin/ferret: project.clj
	mkdir -p bin/
	lein uberjar
	cat resources/jar-sh-header bin/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv bin/target/ferret.jar bin/ferret.jar

# tell make how to compile Ferret lisp to C++
%.cpp: %.clj
	bin/ferret -i $<
	$(call static_check,$@)

# each compiler/framework to be tested get an extensiton. 
# i.e all cpp files compiled with g++ will have .gcc extension

%.gcc: %.cpp
	g++ $(CPPFLAGS) $(CPP_SANITIZE_FLAGS) -x c++ $< -o $@
	$@ 1 2

%.clang: %.cpp
	clang++ $(CPPFLAGS) -x c++ $< -o $@
	valgrind --quiet --leak-check=full --error-exitcode=1 --track-origins=yes $@ 1 2

%.cxx: %.cpp
	$(CXX) $(CPPFLAGS) -x c++ $< -o $@
	valgrind --quiet --leak-check=full --error-exitcode=1 --track-origins=yes ./$@ 1 2

%.ino: CPPCHECK_CONF=-DFERRET_HARDWARE_ARDUINO
%.ino: %.cpp
	mv $< $@
	arduino --verify --board arduino:avr:uno $@

# list of unit tests to run againts the current build
NATIVE_TESTS = test/native/fixed_real.cpp                  \
               test/native/matrix.cpp                      \
               test/native/container_array.cpp             \
               test/native/bitset.cpp                      \
               test/native/memory_pool.cpp

CORE_TESTS = test/core/module.clj                     \
	     test/core/module_unit_test.clj           \
             test/core/module_import_empty_aux_a.clj  \
             test/core/module_import_empty_aux_b.clj  \
             test/core/allocator_api.clj              \
             test/core/core.clj                       \
             test/core/fixed_num.clj                  \
             test/core/io/file.clj                    \
             test/core/net/multicast.clj              \
             test/core/io/serial.clj                  \
             test/core/concurrency.clj

EMBEDDED_TESTS = test/embedded/blink/blink.clj              \
	         test/embedded/blink-multi/blink-multi.clj  \
		 test/embedded/bounce_pin/bounce_pin.clj    \
	         test/embedded/interrupt/interrupt.clj

# assign tests to compilers
CLANG_OBJS = $(NATIVE_TESTS:.cpp=.clang)   $(CORE_TESTS:.clj=.clang)
GCC_OBJS   = $(NATIVE_TESTS:.cpp=.gcc)     $(CORE_TESTS:.clj=.gcc)
CXX_OBJS   = $(NATIVE_TESTS:.cpp=.cxx)     $(CORE_TESTS:.clj=.cxx)
INO_OBJS   = $(EMBEDDED_TESTS:.clj=.ino)

test-compiler: project.clj
	lein test
test-core: bin/ferret $(CXX_OBJS)
test-embedded: bin/ferret $(INO_OBJS)
test-all: bin/ferret test-compiler $(GCC_OBJS) $(CLANG_OBJS) $(INO_OBJS)
test-release: test-all

# rules for preparing a release
deb:    bin/ferret
	mkdir -p deb/usr/bin
	cp bin/ferret deb/usr/bin/
	mkdir -p deb/DEBIAN
	cp resources/deb-package-conf deb/DEBIAN/control
	echo "Version: ${VERSION}" >> deb/DEBIAN/control
	dpkg -b deb ferret-lisp.deb
	rm -rf deb
	mv ferret-lisp.deb bin/
deb-repo: deb
	mkdir -p bin/debian-repo/conf/
	cp resources/deb-repo-conf bin/debian-repo/conf/distributions
	reprepro -b bin/debian-repo/ includedeb ferret-lisp bin/ferret-lisp.deb
clojars: 
	lein deploy
docs:   project.clj
	wget https://s3.amazonaws.com/ferret-lang.org/build-artifacts/clojure-mode-extra-font-locking.el
	emacs -nw -Q --batch -l resources/tangle-docs
	mkdir -p docs/
	mv ferret-manual.html docs/
	rm clojure-mode-extra-font-locking.el
release: clean test-release deb-repo docs clojars
	mkdir -p release/builds/
	mv bin/ferret* release/builds/
	cp release/builds/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv bin/debian-repo release/
	mv docs/ferret-manual.html release/index.html
	rm -rf bin/ docs/

# rules for managing the docker files used by the CI
DOCKER_RUN = docker run --rm -i \
		-e LEIN_JVM_OPTS='-Dhttps.protocols=TLSv1.2' \
		-e LEIN_USERNAME='${LEIN_USERNAME}' \
		-e LEIN_PASSWORD='${LEIN_PASSWORD}' \
		-t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build

docker-build: project.clj
	cd resources/ferret-build/ && \
	   docker build -t nakkaya/ferret-build:latest -t nakkaya/ferret-build:${VERSION} .
	docker push nakkaya/ferret-build:${VERSION}
	docker push nakkaya/ferret-build:latest
docker-bash:
	 ${DOCKER_RUN} /bin/bash
docker-release:
	 ${DOCKER_RUN} /bin/bash -c 'make release'
docker-test:
	 ${DOCKER_RUN} /bin/bash -c 'make test-all'
docker-test-release:
	 ${DOCKER_RUN} /bin/bash -c 'make test-release'
