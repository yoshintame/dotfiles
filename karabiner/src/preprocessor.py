#!/usr/bin/env python3
import yaml
import json
from jinja2 import Environment, FileSystemLoader, PackageLoader, StrictUndefined
import argparse

from pprint import pprint


def render_yaml_template(variable_file, jinja_template_file):
    with open(variable_file, "r") as file:
        try:
            data = yaml.safe_load(file)
        except yaml.YAMLError as err:
            print(err)

    pprint(data)

    env = Environment(
        loader=FileSystemLoader(searchpath="./"),
        trim_blocks=True,
        lstrip_blocks=True,
        undefined=StrictUndefined,
    )

    template = env.get_template(name=jinja_template_file)
    out_data = template.render(data)

    with open("output/hyperkey.yaml", "w") as file:
        file.write(out_data)

    print("Successfully generated hyperkey.yaml in ./output directory")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script for preproceesing configuration file with variable substitution")
    parser.add_argument("variables_file", help="yaml file containing variables")
    parser.add_argument("templates_file", help="j2 file with configuration template")
    args = parser.parse_args()

    render_yaml_template(variable_file=args.variables_file, jinja_template_file=args.templates_file)