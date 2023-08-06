import os
import subprocess

def read_manifest_dependencies(module_path):
    manifest_file = os.path.join(module_path, '__manifest__.py')
    dependencies = []

    with open(manifest_file, 'r') as f:
        for line in f:
            if line.strip().startswith("'depends':"):
                dependencies = line.strip().split(':')[1].strip()[1:-1].split(',')
                dependencies = [dep.strip() for dep in dependencies]

    return dependencies

def install_module_dependencies(module_path):
    dependencies = read_manifest_dependencies(module_path)

    for dependency in dependencies:
        subprocess.run(['pip', 'install', dependency])

if __name__ == '__main__':
    # Replace '/path/to/modules' with the path to the directory containing your custom modules
    modules_path = '/path/to/modules'

    for module_name in os.listdir(modules_path):
        module_path = os.path.join(modules_path, module_name)
        if os.path.isdir(module_path):
            install_module_dependencies(module_path)
