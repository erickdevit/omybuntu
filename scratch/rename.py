import os
import re

TARGET_DIR = "/home/erick/repos/omarchy"

def replace_text_in_file(filepath):
    # Skip binary files by trying to read as utf-8
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return # Skip binary or non-utf-8 files
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return

    # Replace occurrences
    new_content = content.replace("omarchy", "omybuntu")
    new_content = new_content.replace("OMARCHY", "OMYBUNTU")
    new_content = new_content.replace("Omarchy", "Omybuntu")

    if new_content != content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated content in {filepath}")
        except Exception as e:
            print(f"Error writing to {filepath}: {e}")

def get_new_name(name):
    # Replace omarchy variations in the name
    new_name = name.replace("omarchy", "omybuntu")
    new_name = new_name.replace("OMARCHY", "OMYBUNTU")
    new_name = new_name.replace("Omarchy", "Omybuntu")
    return new_name

def process_directory(directory):
    for root, dirs, files in os.walk(directory, topdown=False):
        # Ignore .git
        if '.git' in root.split(os.sep):
            continue

        # Process file contents and then rename files
        for name in files:
            filepath = os.path.join(root, name)
            # Make sure we're not touching the script itself while we're at it, just in case
            if filepath == os.path.abspath(__file__):
                continue

            replace_text_in_file(filepath)
            
            new_name = get_new_name(name)
            if new_name != name:
                new_filepath = os.path.join(root, new_name)
                os.rename(filepath, new_filepath)
                print(f"Renamed file: {filepath} -> {new_filepath}")

        # Rename directories
        for name in dirs:
            if name == '.git':
                continue
            new_name = get_new_name(name)
            if new_name != name:
                dirpath = os.path.join(root, name)
                new_dirpath = os.path.join(root, new_name)
                os.rename(dirpath, new_dirpath)
                print(f"Renamed dir: {dirpath} -> {new_dirpath}")

if __name__ == "__main__":
    process_directory(TARGET_DIR)
