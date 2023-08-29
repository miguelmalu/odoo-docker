import os
import sys
import ast

def set_working_directory():
    # Get the parent directory of the script's directory
    og_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    # Get the working directory name
    og_folder = os.path.basename(og_dir)
    # Navigate to the working directory
    os.chdir(og_dir)

def extract_addons_requeriments(addons_dir):
    addons_requeriments = []

    for addon_name in os.listdir(addons_dir):
        addon_path = os.path.join(addons_dir, addon_name)
        if os.path.isdir(addon_path):
            manifest_file = os.path.join(addon_path, '__manifest__.py')
            if os.path.exists(manifest_file):
                with open(manifest_file, 'r') as f:
                    addon_info_str = f.read()
                    addon_info = ast.literal_eval(addon_info_str)
                    addons_requeriments.extend(addon_info.get("external_dependencies", {}).get("python", []))
    # Remove duplicates from lists
    return list(set(addons_requeriments))

def write_addons_requeriments(addons_requeriments):
    try:
        with open('addons/addons_requeriments.txt', 'w') as f:
            for i, item in enumerate(addons_requeriments):
                if i < len(addons_requeriments) - 1:
                    f.write(item + '\n')
                else:
                    f.write(item)
    except Exception as e:
        print(f"Error creating 'addons_requeriments.txt': {e}")
        sys.exit(1)
    print("'addons_requeriments.txt' saved in addons folder.")

def main():
    set_working_directory()
    addons_requeriments = extract_addons_requeriments("addons")
    write_addons_requeriments(addons_requeriments)

if __name__ == "__main__":
    main()
