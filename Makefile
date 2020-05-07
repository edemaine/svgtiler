.PHONY: all build examples test

all: build

build:
	npm install
	#npm run prepare

examples:
	for example in examples/*; do \
	  make -C $$example ; \
	done

test:
	java -Xss1024k -jar node_modules/vnu-jar/build/dist/vnu.jar \
	  --skip-non-svg --verbose examples
