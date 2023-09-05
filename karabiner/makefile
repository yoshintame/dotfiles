preprocess:
	python3 ./src/preprocessor.py variables.yaml hyperkey.yaml.j2

compile: preprocess
	yq eval output/hyperkey.yaml -o=json > output/hyperkey.json

install: compile
	mkdir -p $$HOME/.config/karabiner/assets/complex_modifications/
	cp output/hyperkey.json $$HOME/.config/karabiner/assets/complex_modifications/

all:
	mkdir -p $$HOME/.config/karabiner/
	cp karabiner.json $$HOME/.config/karabiner/

.PHONY: compile,install,all,preprocess