DIR = $(shell pwd)
DOCKER_RUN = docker run --rm -i -t -v "${DIR}":/ferret/ -w /ferret/ nakkaya/ferret-build
LEIN = cd src/ && lein

MAJOR_VERSION = $(shell git describe --abbrev=0 --tags)
MINOR_VERSION = $(shell git rev-list ${MAJOR_VERSION}.. --count)

.PHONY: tangle test build packr docs release docker-release clean

tangle:
	emacs -nw -Q --batch --eval "(progn (require 'org) (setq org-babel-use-quick-and-dirty-noweb-expansion t) (require 'ob) (find-file \"ferret.org\") (org-babel-tangle))"
test:	tangle
	${LEIN} test
build:  test
	${LEIN} uberjar && cat resources/bash_executable_stub.sh target/ferret.jar > ../ferret && chmod +x ../ferret
packr:  
	cd src/ && bash resources/platform_builds.sh
deb:  
	mkdir -p ./deb/usr/bin
	cp ferret ./deb/usr/bin/
	mkdir -p ./deb/DEBIAN
	cp src/resources/deb-control ./deb/DEBIAN/control
	echo "Version: ${MAJOR_VERSION}.${MINOR_VERSION}" >> ./deb/DEBIAN/control
	dpkg -b ./deb ./ferret-lisp.deb
	rm -rf ./deb
deb-repo: deb
	mkdir -p debian-repo/conf/
	cp src/resources/deb-repo-config ./debian-repo/conf/distributions
	reprepro -b ./debian-repo/ includedeb ferret-lisp ferret-lisp.deb
docs:
	emacs -nw -Q --batch -l src/resources/tangle-docs.el
release: build packr deb-repo docs
	mkdir release/
	mkdir release/builds/
	mv ferret release/builds/
	cp src/target/ferret.jar release/builds/ferret-`git rev-parse --short HEAD`.jar
	mv src/target/ferret.jar release/builds/
	mv src/ferret-linux-amd64.zip release/builds/
	mv src/ferret-macosx-x86_64.zip release/builds/
	mv src/ferret-windows-amd64.zip release/builds/
	mv debian-repo release/
	mv ferret-manual.html release/index.html
	cp -R org-mode-assets release/ferret-styles
docker-release:
	 ${DOCKER_RUN} /bin/bash -c 'make release'
clean:
	rm -rf src/ release/ ferret ferret-manual.html ferret-lisp.deb debian-repo/
