init-linux:
	npm install
	npm run install-linux

init-windows:
	npm install
	npm run install-windows

build-linux:
	npm run build-linux

build-windows:
	npm run build-windows

watch-linux:
	npm run watch-linux

watch-windows:
	npm run watch-windows

clean-linux:
	rm -rf .compiler .thirdparty dist

clean-windows:
	rd /s /q .compiler
	rd /s /q .thirdparty
	rd /s /q dist