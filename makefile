.PHONY: test build clean ai dev bin
.DEFAULT_GOAL := bin
NICK = tog

tog:
	dart ./main.dart \
	--output=ai.txt \
	--folder-recursive="." \
	--ignore-folders=.dart_tool \
	--ignore-folders=.github \
	--ignore-folders=build \
	--ignore-folders=.idea \
	--ignore-folders=.git \
	--ignore-extensions=lock \
	--ignore-files=LICENSE.md \
	--ignore-files=makefile \
	--ignore-files=.gitignore


dev:
	dart compile exe -o ~/bin/$(NICK) main.dart

test:
	dart pub get
	dart analyze --fatal-warnings
	dart test tests.dart --exclude-tags=skip-ci

build:
	dart pub get
	mkdir -p build
ifeq ($(OS),Windows_NT)
	dart compile exe main.dart -o build/$(NICK)-windows-$(PROCESSOR_ARCHITECTURE)
	gzip --best --keep build/$(NICK)-windows-$(PROCESSOR_ARCHITECTURE)
else
	dart compile exe main.dart -o build/$(NICK)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
	gzip --best --keep build/$(NICK)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
endif

clean:
	rm -rf build

bin:
	dart compile exe -o ~/bin/$(NICK) main.dart
