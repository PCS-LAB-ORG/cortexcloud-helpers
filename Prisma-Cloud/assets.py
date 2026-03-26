import json
import sys
import csv
import os
import requests as req

api = ''

"""
Check the result of a restful API call
"""
def result_ok(result, message):
    if ( not result.ok ):
        print(message)
        result.raise_for_status()

"""
Authenticate against Prisma cloud. Return authentication JWT token
"""
def auth_prisma():
    global api
    api = os.getenv('PRISMA_API_URL')
    username = os.getenv('PRISMA_ACCESS_KEY_ID')
    password = os.getenv('PRISMA_SECRET_KEY')
    prismaId = os.getenv('PRISMA_ID')
    if ( api is None or username is None or password is None or prismaId is None):
        print('Missing environment variables')
        sys.exit(1)

    payload = { 'username': username, 'password': password }
    headers = { 'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8' }

    result = req.post(f"{api}/login", data=json.dumps(payload), headers=headers, timeout=5)
    result_ok(result,'Could not authenticate to Prisma.')

    return result.json()['token']

"""
Renews existing token. Returns new token to use.
"""
def extend_token(mytoken):
    headers =  {'Accept': 'application/json; charset=UTF-8','x-redlock-auth': mytoken}
    result = req.get(f"{api}/auth_token/extend", headers=headers, timeout=5)
    result_ok(result, 'Could not extend current token.')
    return result.json()['token']

"""
Create headers for the RESTful API calls, returns a headers object.
"""
def create_headers(token):
    return { 'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8','x-redlock-auth': token}

"""
Retrieve CAS Assets Raw Meta Data
"""
def get_cas_assets():
    token = auth_prisma()
    headers = create_headers(token)
    payload = json.dumps({
    "query": f"""
    {{
        ciInstances(where: {{ customerName: "{os.getenv('PRISMA_ID')}" }}) {{
            ciPlugins {{
                shortName
                version
                longName
                isEnabled
                ciInstancesAggregate {{
                    count
                }}
                ciInstances {{
                    name
                }}
                jenkinsVulnerabilities {{
                    name
                    url
                    vulnerabilityId
                    scores {{
                        cve
                        cvssScore
                        cveDetailed
                    }}
                }}
            }}
        }}
    }}
    """
})
    
    819313206748390400

    # Get all build policies
    result = req.post(f"{api}/bridgecrew/api/v1/assets/graphql", headers=headers, data=payload, timeout=30)
    result_ok(result,'Could not get asset information.')
    json_to_csv(result.json()["data"])



def json_to_csv(data):
    headers = ["Plugin Name", "Version", "IsEnabled", "Installed on", "Vulnerabilities", "Highest severity"]
    rows = []
    
    for ci_instance in data["ciInstances"]:
        for plugin in ci_instance["ciPlugins"]:
            long_name = plugin["longName"]
            version = plugin["version"]
            try:
                is_enabled = plugin["isEnabled"]
            except NameError:
                is_enabled = True
            ci_instances = ci_instance["ciPlugins"][0]["ciInstances"][0]["name"] 
            jenkins_vulnerabilities = plugin["jenkinsVulnerabilities"]
            vulnerabilities = []
            highest_severity = 0.0
            for vulnerability in jenkins_vulnerabilities:
                vulnerability_id = vulnerability["scores"][0]["cve"]
                vulnerability_severity = vulnerability["scores"][0]["cvssScore"]
                vulnerabilities.append(vulnerability_id)
                highest_severity = max(highest_severity, vulnerability_severity)
            
            row = [long_name, version, is_enabled, ci_instances, ','.join(vulnerabilities), highest_severity]
            rows.append(row)
    
    with open('output.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(headers)
        writer.writerows(rows)


if __name__ == '__main__':
    print('Get CAS Assets Raw Meta Data -  0.0.1')
    get_cas_assets()
    print('Executed Successfully, check your output.csv')
