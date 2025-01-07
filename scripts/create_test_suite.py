#!env python

import glob
import pathlib
import shutil
import subprocess
import tempfile

import yaml


def clone_repo(url):
    """
    Clone a Git repository to a temporary directory.

    Args:
        url (str): The URL of the repository to clone.

    Returns:
        str: The path to the temporary directory containing the cloned repository.
    """
    try:
        # Create a temporary directory
        temp_dir = tempfile.mkdtemp()

        # Clone the repository into the temporary directory
        subprocess.run(["git", "clone", url, temp_dir])

        return temp_dir
    except subprocess.CalledProcessError as e:
        print(f"Error cloning repository: {e}")
        return None
    except Exception as e:
        print(f"Error creating temporary directory: {e}")
        return None


def escape(input_string):
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


# def escape(input_string):
#     """
#     Escapes quotes in a given string, and escapes backslashes only when they are not part of control characters like \\n or \\t.
#
#     Args:
#         input_string (str): The input string to be processed.
#
#     Returns:
#         str: The input string with quotes and backslashes (except in control characters) escaped.
#     """
#     import re
#
#     # Escape quotes
#     escaped_string = input_string.replace('"', '\\"').replace("'", "\\'")
#     # Escape backslashes not followed by a control character
#     escaped_string = re.sub(r"\\(?!n|t|r|b|f|\\)", r"\\\\", escaped_string)
#     return escaped_string


def fix_chars(input_string):
    """
    In the test Suite some characters are displayed with spcial characters

    ␣ is used for trailing space characters
    Hard tabs are reresented by one of: (expanding to 4 spaces)
    ———»
    ——»
    —»
    »
    ↵ us used to show trailing newline characters
    ∎ is used at the end when there is no final newline character
    ← indicates a carriage return character
    ⇔ indicates a byte order mark (BOM) character

    Args:
        input_string (str): The input string to be processed.

    Returns:
        str: The input string with quotes and newlines escaped.
    """
    return (
        input_string.replace("␣", " ")
        .replace("———»", "\t\t\t\t")
        .replace("——»", "\t\t\t")
        .replace("—»", "\t\t")
        .replace("»", "\t")
        .replace("↵", "\n")
        .replace("∎", "")
        .replace("←", "\r")
        .replace("⇔", "\ufeff")
    )


def string_to_hashtags(input_string):
    """
    Convert a string to a string with each word prefixed with a hashtag.

    Args:
        input_string (str): The input string to convert.

    Returns:
        str: The input string with each word prefixed with a hashtag.
    """
    return " ".join(f"#{word}" for word in input_string.split())


# Clone the YAML test suite repository to a temporary directory
url = "https://github.com/yaml/yaml-test-suite.git"
temp_dir = clone_repo(url)

if not temp_dir:
    print("❌ Cloning of the repository failed.")
    exit()

# Don't forget to clean up the temporary directory when you're done
if not pathlib.Path(temp_dir).is_dir():
    print("❌ Can not find repository")
else:
    with open("spec/testsuite/tree_spec.lua", "w") as f:
        f.write('local assert = require("luassert")\n')
        f.write('local yalua = require("yamlparser")\n')
        f.write(f'describe("Run the YAML test #suite, compare with TREE", function()\n')
        # try:
        for file in glob.glob(f"{temp_dir}/src/*.yaml"):
            with open(file, "r") as yaml_file:
                path = pathlib.Path(file)
                yaml_data = yaml.safe_load(yaml_file)

                if not "fail" in yaml_data[0]:  # and "yaml" in yaml_data[0]:
                    tags = ""
                    if yaml_data[0]["tags"]:
                        tags = string_to_hashtags(yaml_data[0]["tags"])
                    f.write(
                        f'  it("should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem} tags: {tags}", function()\n'
                    )
                    f.write(
                        f'  print("### should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}")\n'
                    )
                    f.write(
                        f'    local input = "{escape(fix_chars(yaml_data[0]["yaml"]))}"\n'
                    )
                    f.write(
                        f'    local tree = "{yaml_data[0]["tree"].replace('"', '\\"').replace("'", "\\'").replace("\n", "\\n")}"\n'
                    )
                    f.write("local result = yalua.stream(input)\n")
                    f.write("assert.is.Same(tree, result)\n")
                    f.write(f"  end)\n")
        f.write(f"end)\n\n")

    with open("spec/testsuite/json_spec.lua", "w") as f:
        f.write('local assert = require("luassert")\n')
        f.write('local yalua = require("yalua")\n')
        f.write('local rapidjson = require("rapidjson")\n')
        f.write(f'describe("Run the YAML test #suite, compare with JSON", function()\n')
        for file in glob.glob(f"{temp_dir}/src/*.yaml"):
            with open(file, "r") as yaml_file:
                path = pathlib.Path(file)
                yaml_data = yaml.safe_load(yaml_file)

                if not "fail" in yaml_data[0] and "json" in yaml_data[0]:
                    tags = ""
                    if yaml_data[0]["tags"]:
                        tags = string_to_hashtags(yaml_data[0]["tags"])
                    f.write(
                        f'  it("should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}, tags: {tags}", function()\n'
                    )
                    f.write(
                        f'  print("### should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}")\n'
                    )
                    f.write(
                        f'    local input = "{escape(fix_chars(yaml_data[0]["yaml"]))}"\n'
                    )
                    f.write(f'    local tree = "{escape(yaml_data[0]["json"])}"\n')
                    f.write("local result = yalua.decode(input)\n")
                    f.write("assert.is.Same(rapidjson.decode(tree), result)\n")
                    f.write(f"  end)\n")
        f.write(f"end)\n\n")


try:
    shutil.rmtree(temp_dir)
except FileNotFoundError:
    print(f"❌ Directory '{temp_dir}' not found.")
    exit(1)
except Exception as e:
    print(f"❌ Error deleting directory: {e}")
    exit(1)

print("✅ Test suite generated")
