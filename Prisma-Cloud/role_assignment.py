import json
import os
import sys
import requests as req

api = os.getenv('PRISMA_API_URL')
username = os.getenv('PRISMA_ACCESS_KEY_ID')
password = os.getenv('PRISMA_SECRET_KEY')
role = os.getenv('PRISMA_ROLE')

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

def get_repos():
    response = make_request("GET", "code/api/v2/repositories")
    repo_ids = []

    data = response.json()['repositories']

    for item in data:
        repo_ids.append(item.get('id'))
    return repo_ids

def get_role_id(role):
    try:
        data = make_request("GET", "user/role")
        for item in data.json():
            if item.get('name') == role:
                return {
                    "id": item.get('id'),
                    "roleType": item.get('roleType')
                }
        # If 'specified role' not found, return None
        return None
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)



def assign_repos():
    try:
        role_id = get_role_id(role)
        repos_id = get_repos()
        payload = {
            "accountGroupIds": [],
            "resourceListIds": [],
            "roleType": role_id['roleType'], 
            "codeRepositoryIds": repos_id
            }
        result = make_request("PUT", f"user/role/{role_id['id']}", payload)
        return result
    except Exception as e:
        print(f"Error: {e}")
        color_print('Error assigning repositories', Colors.RED)

if __name__ == '__main__':
    color_print('CAS - Assign all onboarded Repos to Developer role - 0.0.1', Colors.GREEN)
    try:
        assign_repos()
        color_print('Done', Colors.GREEN)
    except Exception as e:
        color_print(f"Error: {e}", Colors.RED)