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
    return input_string.replace('"', '\\"').replace("'", "\\'").replace("\n", "\\n")


# Clone the YAML test suite repository to a temporary directory
url = "https://github.com/yaml/yaml-test-suite.git"
# temp_dir = clone_repo(url)
temp_dir = "/tmp/tmpxqapx_bt/"

# Don't forget to clean up the temporary directory when you're done
if temp_dir:
    print(f'describe("Test the YAML LLM promopts", function()')
    # try:
    for file in glob.glob(f"{temp_dir}/src/*.yaml"):
        with open(file, "r") as f:
            path = pathlib.Path(file)
            yaml_data = yaml.safe_load(f)
            print(
                f'  it("should parse the {escape(yaml_data[0]["name"])}, file: #{path.stem}", function()'
            )
            if "fail" in yaml_data[0]:
                print("    -- test will fail")
            else:
                if "dump" in yaml_data[0]:
                    print(f'    local input = [[{yaml_data[0]["dump"]}]]')
                print(f'    local tree = [[{yaml_data[0]["tree"]}]]')
            print(f"  end)\n")

    # shutil.rmtree(temp_dir)
    print(f"end)")

    # except Exception as e:
    #     print(f"Error cleaning up temporary directory: {e}")
