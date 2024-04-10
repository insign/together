.PHONY: test build clean ai dev

ai:
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
	dart compile exe -o ~/bin/tog main.dart

test:
	dart pub get
	dart analyze --fatal-warnings
	# dart test --exclude-tags=skip-ci

build:
	dart pub get
	mkdir -p build
ifeq ($(OS),Windows_NT)
	dart compile exe main.dart -o build/tog-windows-$(PROCESSOR_ARCHITECTURE)
	gzip --best --keep build/tog-windows-$(PROCESSOR_ARCHITECTURE)
else
	dart compile exe main.dart -o build/tog-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
	gzip --best --keep build/tog-$$(uname -s | tr '[:upper:]' '[:lower:]')-$$(uname -m)
endif

clean:
	rm -rf build
