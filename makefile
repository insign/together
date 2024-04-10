ai:
	dart ./main.dart \
	--output=ai.txt \
	--folder-recursive="." \
	--ignore-folders=.dart_tool \
	--ignore-folders=.github \
	--ignore-folders=build \
	--ignore-folders=.idea \
	--ignore-extensions=lock \
	--ignore-files=LICENSE.md \
	--ignore-files=makefile \
	--ignore-files=.gitignore
