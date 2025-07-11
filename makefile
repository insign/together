.PHONY: test build clean ai dev bin gen
.DEFAULT_GOAL := bin
NICK = tog

tog:
	dart run bin/$(NICK).dart * **/* --gitignore --ignore-extensions=lock --ignore-files=LICENSE.md,makefile,.gitignore

dev:
	dart compile exe -o ~/bin/$(NICK) bin/$(NICK).dart

test:
	dart pub get
	dart analyze --fatal-warnings
	dart test --exclude-tags=skip-ci

build:
	dart pub get
	mkdir -p build
ifeq ($(OS),Windows_NT)
	dart compile exe bin/$(NICK).dart -o build/$(NICK)-windows-$(PROCESSOR_ARCHITECTURE)
	gzip --best --keep build/$(NICK)-windows-$(PROCESSOR_ARCHITECTURE)
else
	dart compile exe bin/$(NICK).dart -o build/$(NICK)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
	gzip --best --keep build/$(NICK)-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
endif

clean:
	rm -rf build

bin:
	dart compile exe -o ~/bin/$(NICK) bin/$(NICK).dart
