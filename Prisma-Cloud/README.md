# CAS SCRIPTS

# Role Assignment Script

**Overview**
This script is used to assign roles and repositories to users in the Prisma API.

**Usage**
1. Update the `PRISMA_API_URL` and `PRISMA_ACCESS_KEY_ID` environment variables with your Prisma API URL and access key ID.
2. Run the script using Python (e.g., `role_assignment.py`).
3. The script will assign the specified role to the user and add/remove repositories as needed.

**Script Details**

### Functions

*   `authenticate`: Authenticates with the Prisma API using the provided credentials.
*   `create_headers`: Creates a dictionary of HTTP headers for use in subsequent requests.
*   `make_request`: Sends a request to the Prisma API and returns the response.
*   `get_repos`: Retrieves a list of repository IDs from the Prisma API.
*   `get_role_id`: Retrieves the ID of a specified role from the Prisma API.
*   `assign_repos`: Assigns a specified role to a user and adds/removes repositories as needed.

### Error Handling**

The script includes robust error handling using `try/except` blocks. If an error occurs during execution, it will be printed and the program will exit with an error message.

**Colored Text Output**
The script uses the `Colors` class to print colored text output. This provides a more user-friendly experience.

### Known Issues

*   None known at this time.

**Troubleshooting**

If you encounter any issues while using this script, please refer to the Prisma API documentation for troubleshooting tips and error handling best practices.

# Download a json file of repositories metadata from Prisma Cloud

Simple python 3 script to initiate and download a json file of repositories metadata from Prisma Cloud.

To get started:

```
export PRISMA_API_URL=<your value>
export PRISMA_ACCESS_KEY_ID=<your value>
export PRISMA_SECRET_KEY=<your value>

# Very first run
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

python3 metadata.py

```
Your JSON file will be saved in the current directory

