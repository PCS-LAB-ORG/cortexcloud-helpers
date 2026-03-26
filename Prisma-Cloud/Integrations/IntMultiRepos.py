import json
import os
import sys
import requests as req

api = os.getenv('PRISMA_API_URL')
username = os.getenv('PRISMA_ACCESS_KEY_ID')
password = os.getenv('PRISMA_SECRET_KEY')
intId = os.getenv('PRISMA_INT_ID')


class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    END = '\033[0m'
    CYAN = '\033[96m'

def color_print(text, color):
    print(color + text + Colors.END)
    
if api is None or username is None or password is None:
    color_print("🚨 Attention: It seems some environment variables are missing! Please verify your configuration and try again. 🧐", Colors.YELLOW)
    sys.exit(1)


def authenticate():
    try:
        payload = {'username': username, 'password': password}
        headers = {'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8'}
        result = req.post(f"{api}/login", data=json.dumps(payload), headers=headers, timeout=30)
        result.raise_for_status()
        return result.json()['token']
    except req.exceptions.RequestException as e:
        print(f"Error: {e}")
        sys.exit(1)

def create_headers(token):
    try:
        return {'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8',
                'x-redlock-auth': token}
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def make_request(method, endpoint, payload=None):
    try:
        token = authenticate()  # Assume this function returns a token
        headers = create_headers(token)  # Assume this function creates the necessary headers
        
        if method == "GET":
            result = req.get(f"{api}/{endpoint}", headers=headers, timeout=30)
        elif method == "POST":
            result = req.post(f"{api}/{endpoint}", headers=headers, data=json.dumps(payload), timeout=30)
        elif method == "PUT":
            result = req.put(f"{api}/{endpoint}", headers=headers, data=json.dumps(payload), timeout=30)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
        
        result.raise_for_status()
        return result
    except req.exceptions.RequestException as e:
        print(f"Error: {e}")
        sys.exit(1)

def update_integration():
    try:
        color_print("📄 Reading repositories from 'input.txt' for integration...", Colors.CYAN)
        with open('input.txt', 'r') as file:
            repositories = [line.strip() for line in file.readlines()]
        if not repositories:
            color_print("⚠️  No repositories found in 'input.txt'. Integration aborted.", Colors.YELLOW)
            return
        color_print("🔄 Preparing to integrate the following repositories:", Colors.CYAN)
        for i, repo in enumerate(repositories, start=1):
            print(f"   {i}. {repo}")
        payload = {
        "integrationId": intId,
        "repositoriesNames": repositories    
        } 
        color_print(f"\n🚀 Sending payload to onboard {len(repositories)} repositories...", Colors.GREEN) 
        response = make_request("POST", f"code/api/v2/repositories", payload)
        if response.status_code == 202:
            color_print("✅ Integration updated successfully!", Colors.GREEN)
        return response
    except FileNotFoundError:
        color_print("❌ Error: 'input.txt' not found. Please ensure the file exists.", Colors.RED)
    except Exception as e:
        color_print(f"❌ Error: {e}", Colors.RED)


def get_repos():
    response = make_request("GET", "code/api/v2/repositories")

    data = response.json()['repositories']

    if not data:
        print("No repositories found.")
        return

    print("Onboarded repositories:")
    for item in data:
        source = item.get('source')
        repo_id = item.get('id')
        repo_name = item.get('repository')
        # Display in a user-friendly format
        print(f"🔹 Source: {source}")
        print(f"   ├── ID: {repo_id}")
        print(f"   └── Name: {repo_name}\n")
    
    print("✅ These are the onboarded repositories.")

if __name__ == '__main__':
    color_print('🎯 CAS - Integrate Multiple Repositories - v0.0.1', Colors.GREEN)
    try:
        # Call the update integration function
        color_print('🔄 Updating integration for repositories...', Colors.CYAN)
        update_integration()

        # Fetch and print the onboarded repositories
        color_print('📦 Fetching onboarded repositories:', Colors.CYAN)
        get_repos()

        # Indicate that the process is done
        color_print('✅ Done. All repositories have been onboarded successfully.', Colors.GREEN)
    except Exception as e:
        color_print(f"❌ Error: {e}", Colors.RED)
