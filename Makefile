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
	mkdir -p bin/
	${LEIN} uberjar
	cat src/resources/bash_executable_stub.sh src/target/ferret.jar > bin/ferret
	chmod +x bin/ferret
	mv src/target/ferret.jar bin/ferret.jar
packr:  
	cd src/ && bash resources/platform_builds.sh
	mv src/*.zip bin/
deb:  
	mkdir -p deb/usr/bin
	cp bin/ferret deb/usr/bin/
	mkdir -p deb/DEBIAN
	cp src/resources/deb-control deb/DEBIAN/control
	echo "Version: ${MAJOR_VERSION}.${MINOR_VERSION}" >> deb/DEBIAN/control
	dpkg -b deb ferret-lisp.deb
	rm -rf deb
	mv ferret-lisp.deb bin/
deb-repo: deb
	mkdir -p bin/debian-repo/conf/
	cp src/resources/deb-repo-config bin/debian-repo/conf/distributions
	reprepro -b bin/debian-repo/ includedeb ferret-lisp bin/ferret-lisp.deb
docs:
	wget https://s3.amazonaws.com/ferret-lang.org/build-artifacts/org-mode-assets.zip
	unzip org-mode-assets.zip
	emacs -nw -Q --batch -l src/resources/tangle-docs.el
	mkdir -p docs/
	mv ferret-manual.html docs/
	rm org-mode-assets.zip
	mv org-mode-assets docs/ferret-styles
release: clean build packr deb-repo docs
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
	rm -rf src/ bin/ docs/ release/
