import json
import sys
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
    if ( api is None or username is None or password is None):
        print('Missing environment variables')
        sys.exit(1)

    payload = { 'username': username, 'password': password }
    headers = { 'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8' }

    result = req.post(f"{api}/login", data=json.dumps(payload), headers=headers)
    result_ok(result,'Could not authenticate to Prisma.')

    return result.json()['token']

"""
Renews existing token. Returns new token to use.
"""
def extend_token(mytoken):
    headers =  {'Accept': 'application/json; charset=UTF-8','x-redlock-auth': mytoken}
    result = req.get(f"{api}/auth_token/extend", headers=headers)
    result_ok(result, 'Could not extend current token.')
    return result.json()['token']

"""
Create headers for the RESTful API calls, returns a headers object.
"""
def create_headers(token):
    return { 'Content-Type': 'application/json; charset=UTF-8', 'Accept': 'application/json; charset=UTF-8','x-redlock-auth': token}


def get_ids_and_delete():
    try:
        # Make the first API call to retrieve data
        token = auth_prisma()
        headers = create_headers(token)
        payload = { "filters": { "archived": ["true"]}}
        # payload = { "filters": { "archived": ["true"], "providers":["Github"] }}

        # Get all metadata
        result = req.post(f"{api}/bridgecrew/api/v1/vcs-repository/repositories", headers=headers, data=json.dumps(payload))
        result_ok(result,'Could not get archived repository metadata')
        
        # Initialize list to store deleted ids
        deleted_ids = []
        
        # Process response data
        for item in result.json():
            id_key = item.get('id')
            full_name = item.get('fullName')
            if id_key:
                # Construct URL for delete request
                # Make the delete request
                delete_response = req.delete(f"{api}/bridgecrew/api/v2/repositories/{id_key}", headers=headers)
                delete_response.raise_for_status()  # Raise exception for HTTP errors
                
                # Check if deletion was successful
                if delete_response.status_code == 202:
                    print(f"Successfully deleted item with id '{id_key}' and full name '{full_name}'")
                    deleted_ids.append({"id": id_key, "fullName": full_name})
                else:
                    print(f"Failed to delete item with id '{id_key}' and full name '{full_name}'")
            else:
                print("Missing 'id' key in response item:", item)
        
        # Return the list of deleted ids
        return deleted_ids
    
    except req.RequestException as e:
        print("Error making HTTP request:", e)
        return None
    except Exception as e:
        print("An error occurred:", e)
        return None

# Example usage
deleted_ids = get_ids_and_delete()
if deleted_ids:
    print("Deleted IDs:", deleted_ids)
else:
    print("No IDs were deleted.")
