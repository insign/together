.PHONY: test build clean ai dev bin
.DEFAULT_GOAL := bin
NICK = tog

tog:
	tog * --ignore-folders=.dart_tool,.github,build,.idea,.git --ignore-extensions=lock --ignore-files=LICENSE.md,makefile,.gitignore

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
