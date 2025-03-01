#!/bin/env python

path = "yaml-test-suite/data/tags"

import glob
import pathlib
from typing import Any, Dict, List

import yaml

temp_dir = "./yaml-test-suite"


def prepend_hash(input_string: str):
    """
    Prepend each word in a given string with a hash (#)

    Args:
        input_string (str): The input string

    Returns:
        str: The modified string with each word prepended with a hash
    """
    return " ".join("#" + word for word in input_string.split())


def escape(input_string: str):
    """
    Escapes quotes and newlines in a given string.

    Args:
        input_string (str): The input string to be processed.

    Returns:
        str: The input string with quotes and newlines escaped.
    """
    return (
        input_string.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("'", "\\'")
        .replace("\n", "\\n")
    )


# Don't forget to clean up the temporary directory when you're done
if not pathlib.Path(temp_dir).is_dir():
    print("❌ Can not find repository")
else:
    suite: List[List[Dict[str, Any]]] = []
    for file in glob.glob(f"{temp_dir}/src/*.yaml"):
        test: List[Dict[str, Any]] = []
        with open(file, "r") as yaml_file:
            path = pathlib.Path(file)
            yaml_data = yaml.safe_load(yaml_file)

            for item in yaml_data:
                test_unit: Dict[str, Any] = {}
                test_unit["file"] = path.stem
                for key, value in item.items():
                    if key == "name":
                        test_unit["name"] = value
                    elif key == "from":
                        test_unit["source"] = value
                    elif key == "tags":
                        test_unit["tags"] = value
                    elif key == "fail":
                        test_unit["fail"] = True
                    elif key == "json":
                        test_unit["json"] = value
                    elif key == "dump":
                        test_unit["dump"] = value
                    elif key == "emit":
                        test_unit["emit"] = value
                    elif key == "yaml":
                        test_unit["yaml"] = value
                    elif key == "tree":
                        test_unit["tree"] = value
                    else:
                        print(f"{key}")
                test.append(test_unit)
            suite.append(test)

    test_count = 0
    for c in suite:
        test_count += len(c)
        # print(f"{c[0]['file']}: {c[0]['name']} ({len(c)})")
    print(f"{test_count} tests found")

    # create the tree tests
    with open("spec/testsuite/tree_spec.lua", "w") as f:
        f.write('local assert = require("luassert")\n')
        f.write('local yalua = require("yalua")\n')

        f.write("\nlocal function load_file(file_path)\n")
        f.write('    local file = io.open(file_path, "r")\n')
        f.write("    if not file then\n")
        f.write('        return nil, "File not found"\n')
        f.write("    end\n")
        f.write('    local content = file:read("*all")\n')
        f.write("    file:close()\n")
        f.write("    return content\n")
        f.write("end\n\n")

        f.write("local function remove_trailing_spaces(str)\n")
        f.write('  return str:gsub("^%s+", "")\n')
        f.write("end\n")
        f.write("\n")
        f.write("local function remove_all_trailing_spaces(multiline_str)\n")
        f.write("  local lines = {}\n")
        f.write('  for line in multiline_str:gmatch("[^\\r\\n]+") do\n')
        f.write("    local res = remove_trailing_spaces(line)\n")
        f.write("    table.insert(lines, res)\n")
        f.write("  end\n")
        f.write('  table.insert(lines, "")')
        f.write('  return table.concat(lines, "\\n")\n')
        f.write("end\n\n")

        f.write(f'describe("Run the YAML test #suite, compare with TREE", function()\n')
        for c in suite:
            test_nr = 0
            for test in c:
                name = test.get("name", c[0]["name"])
                tags = prepend_hash(test.get("tags", c[0]["tags"]))
                filename = test.get("file", c[0]["file"])
                file = test.get("file", c[0]["file"])
                the_yaml = test.get("yaml", None)
                if len(c) > 1:
                    file = f"{file}/{test_nr:02d}"
                    the_yaml = f"{the_yaml}/{test_nr:02d}"

                fail = test.get("fail", False)
                tree = test.get("tree", c[0]["tree"])
                f.write(
                    f'  it("should parse the {escape(name)}, file: #{filename} tags: {tags}", function()\n'
                )
                f.write(
                    f'    print("### should parse the {escape(name)}, file: #{filename}")\n'
                )
                f.write(
                    f'    local input = load_file("{temp_dir}/data/{file}/in.yaml")\n'
                )
                if fail:
                    f.write("    local result = yalua.stream(input)\n")
                    f.write("    assert.Equal(nil, result)\n")
                    f.write(f"  end)\n")
                else:
                    f.write(
                        f'    local tree = load_file("{temp_dir}/data/{file}/test.event")\n'
                    )
                    f.write("    local result = yalua.stream(input)\n")
                    f.write(
                        "    assert.is.Same(tree, remove_all_trailing_spaces(result))\n"
                    )
                    f.write(f"  end)\n")

                test_nr += 1
        f.write(f"end)\n\n")
