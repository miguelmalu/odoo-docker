import os
import sys
import requests
from bs4 import BeautifulSoup

def set_working_directory():
    # Get the parent directory of the script's directory
    og_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    # Get the working directory name
    og_folder = os.path.basename(og_dir)
    # Navigate to the working directory
    os.chdir(og_dir)

# Define a function to get the parameter from command-line arguments
def get_target_version():
    if len(sys.argv) < 2:
        print("Usage: python3 get_module_names.py <param>")
        sys.exit(1)
    return sys.argv[1]

# Define a function to fetch module names
def fetch_module_names(target_version):
    # URL of the website you want to scrape
    # Generate the URL based on the status version
    url_suffix = f"{int(float(target_version) * 10) - 10}-{int(float(target_version) * 10)}"
    url = f"https://oca.github.io/OpenUpgrade/modules{url_suffix}.html"

    # Send a GET request to fetch the webpage content
    response = requests.get(url)

    # Check if the request was successful
    if response.status_code == 200:
        # Parse the HTML using BeautifulSoup
        soup = BeautifulSoup(response.content, 'html.parser')

        # Find all rows in the table body
        table_body = soup.find('tbody')
        rows = table_body.find_all('tr')

        # Initialize an empty list to store module names
        module_names = []

        # Iterate through rows and extract module names with status "Nothing to do" or "Done"
        for row in rows:
            columns = row.find_all('td')
            if len(columns) >= 2:
                module_name = columns[0].p.get_text().strip()
                try:
                    module_status_text = columns[1].p.get_text().strip()
                except:
                    module_status_text = None
                if module_status_text and ("Nothing to do" in module_status_text or "Done" in module_status_text):
                    module_names.append(module_name)
                elif columns[0].p.img and "deleted.png" in columns[0].p.img["src"]:
                    module_names.append(module_name)

        return module_names

    else:
        print(f"Failed to retrieve the webpage. Status code: {response.status_code}")
        sys.exit(1)

# Define a function to export module names to a text file
def export_module_names(module_names):
    try:
        with open('scripts/modules_coverage.txt', 'w') as f:
            for i, module in enumerate(module_names):
                if i < len(module_names) - 1:
                    f.write(module + '\n')
                else:
                    f.write(module)
    except Exception as e:
        print(f"Error creating 'modules_coverage.txt': {e}")
        sys.exit(1)
    print("'modules_coverage.txt' temporally saved in scripts folder.")

def main():
    set_working_directory()
    target_version = get_target_version()
    module_names = fetch_module_names(target_version)
    export_module_names(module_names)

if __name__ == "__main__":
    main()

