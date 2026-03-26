import json
import os
import sys
import requests as req

api = os.getenv('PRISMA_API_URL')
username = os.getenv('PRISMA_ACCESS_KEY_ID')
password = os.getenv('PRISMA_SECRET_KEY')

if api is None or username is None or password is None:
    print('Missing environment variables')
    sys.exit(1)

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    END = '\033[0m'

def color_print(text, color):
    print(color + text + Colors.END)

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
        token = authenticate()
        headers = create_headers(token)
        if method == "GET":
            result = req.get(f"{api}/{endpoint}", headers=headers, timeout=30)
        else:
            result = req.put(f"{api}/{endpoint}", headers=headers, data=json.dumps(payload), timeout=30)
        result.raise_for_status()
        return result
    except req.exceptions.RequestException as e:
        print(f"Error: {e}")
        sys.exit(1)


def get_repos(file_path):
    # Read the input file to get all owner and repository combinations
    with open(file_path, 'r') as file:
        lines = [line.strip() for line in file.readlines()]
    
    # Make an API request to fetch repository data
    response = make_request("GET", "code/api/v2/repositories")
    if response.status_code != 200:
        raise Exception("Failed to fetch repositories")
    data = response.json()['repositories']
    
    repo_ids = []
    # Filter repositories based on the owner, repository, and source
    for line in lines:
        owner, repository = line.split('/')
        for item in data:
            if item.get('owner') == owner and item.get('repository') == repository and item.get('source') == 'Github':
                repo_ids.append(item.get('id'))

    return repo_ids


def get_tagRule_id():
    try:
        data = make_request("GET", "code/api/v1/tag-rules")
        for item in data.json():
            if item.get('name') == "yor_trace":
                return {
                    "id": item.get('id'),
                    "name": item.get('name'),
                    "repositories": item.get('repositories')
                }
        # If 'specified tag rule' not found, return None
        return None
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)



def update_tag_rule():
    try:
        tagRule_id = get_tagRule_id()
        file_path = 'input.txt'
        repos_id = get_repos(file_path)
        print(repos_id)
        payload = {
            "name":"yor_trace",
            "description":"Unique traceability tag which links between IaC templates and runtime resources",
            "repositories":repos_id
            }
        result = make_request("PUT", f"code/api/v1/tag-rules/{tagRule_id['id']}", payload)
        result = "good"
        return result
    except Exception as e:
        print(f"Error: {e}")
        color_print('Error updating tag rule', Colors.RED)

if __name__ == '__main__':
    color_print('CAS - Update Yor Tag Rule - 0.0.1', Colors.GREEN)
    try:
        update_tag_rule()
        color_print('Done', Colors.GREEN)
    except Exception as e:
        color_print(f"Error: {e}", Colors.RED)