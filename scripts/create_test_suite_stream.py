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


# Clone the YAML test suite repository to a temporary directory
url = "https://github.com/yaml/yaml-test-suite.git"
# temp_dir = clone_repo(url)
temp_dir = "/tmp/tmpytiz7duo"

# Don't forget to clean up the temporary directory when you're done
if temp_dir:
    print('local assert = require("luassert")')
    print('local yalua = require("parser2")')
    print(f'describe("Test the YAML LLM promopts", function()')
    # try:
    for file in glob.glob(f"{temp_dir}/src/*.yaml"):
        with open(file, "r") as f:
            path = pathlib.Path(file)
            yaml_data = yaml.safe_load(f)

            if not "fail" in yaml_data[0]:  # and "yaml" in yaml_data[0]:
                print(
                    f'  it("should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}", function()'
                )
                print(
                    f'  print("should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}")'
                )
                print(f'    local input = "{escape(fix_chars(yaml_data[0]["yaml"]))}"')
                print(f'    local tree = [[{yaml_data[0]["tree"]}]]')
                print("local result = yalua.stream(input)")
                print("assert.is.Same(tree, result)")
                print(f"  end)\n")

    # shutil.rmtree(temp_dir)
    print(f"end)")

    # except Exception as e:
    #     print(f"Error cleaning up temporary directory: {e}")
