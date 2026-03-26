import csv
import json
import os
import sys
from pcpi import session_loader
from time import sleep
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import pytz

# Setup Logging
# Output formats and files
PROFILE_OUTPUT_FORMAT = 'csv'
PROFILE_OUTPUT_FILE = f"container_profiles_output.{PROFILE_OUTPUT_FORMAT}"
INCIDENT_OUTPUT_FORMAT = 'csv'
INCIDENT_OUTPUT_FILE = f"incidents_output.{INCIDENT_OUTPUT_FORMAT}"
MATCHED_OUTPUT_FILE = "matched_md5_profiles_with_incident_fields.csv"

# Target fields for container profiles
PROFILE_FIELDS = [
    'state', 'learnedStartup', '_id', 'hash', 'image', 'os', 'archived',
    'entrypoint', 'infra', 'processes.static.path', 'processes.static.ppath',
    'processes.static.md5', 'imageID', 'namespace', 'cluster', 'accountIDs'
]

# Target fields for incidents
INCIDENT_FIELDS = [
    '_id', 'cluster', 'filepath', 'md5', 'command', 'provider', 'resourceID',
    'hostname', 'fqdn', 'containerName', 'containerID', 'imageName', 'imageID', 'profileID'
]

# Combined fields for matched profiles output
MATCHED_FIELDS = PROFILE_FIELDS + [
    'incident._id', 'incident.hostname', 'incident.fqdn', 'incident.containerName',
    'incident.containerID', 'incident.imageName', 'incident.imageID', 'incident.profileID'
]

# Utility to safely extract nested fields
def get_nested(data, path):
    keys = path.split('.')
    for key in keys:
        if isinstance(data, list):
            data = data[0] if data else {}
        data = data.get(key, {})
    return data if not isinstance(data, dict) else ""

def extract_profile_fields(profile):
    flat = {}
    for field in PROFILE_FIELDS:
        flat[field] = get_nested(profile, field)
    # accountIDs may be a list; join if needed
    if isinstance(flat.get("accountIDs"), list):
        flat["accountIDs"] = ",".join(flat["accountIDs"])
    return flat

def extract_incident_fields(incident):
    flat = {}
    audit = get_nested(incident, 'audits')
    for field in INCIDENT_FIELDS:
        if field in ['_id', 'hostname', 'fqdn', 'containerName', 'containerID', 'imageName', 'imageID', 'profileID']:
            flat[field] = incident.get(field, '')
        else:
            flat[field] = get_nested(audit, field)
    return flat

# Load Session
try:
    print("Loading session...")
    session_managers = session_loader.load_config()
    session_man = session_managers[0]
    cwp_session = session_man.create_cwp_session()
except Exception as e:
    print(f"Failed to load or authenticate session: {e}")
    exit(1)

# Calculate date range for incidents (last 3 months)
end_date = datetime.now(pytz.UTC)
start_date = end_date - relativedelta(months=3)
from_date = start_date.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
to_date = end_date.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'

# Fetch container profiles
all_profiles = []
limit = 100
offset = 0

try:
    print("Fetching initial batch of container profiles...")
    res = cwp_session.request(
        'GET',
        f'/api/v1/profiles/container?limit={limit}&offset={offset}&project=Central+Console&reverse=false'
    )
    total_count = int(res.headers.get("Total-Count", 0))
    print(f"Total profiles to fetch: {total_count}")

    while offset < total_count:
        print(f"Fetching profile records {offset + 1} to {offset + limit}...")
        try:
            res = cwp_session.request(
                'GET',
                f'/api/v1/profiles/container?limit={limit}&offset={offset}&project=Central+Console&reverse=false'
            )
            res.raise_for_status()
            batch = res.json()
            for profile in batch:
                all_profiles.append(extract_profile_fields(profile))
        except Exception as err:
            print(f"Error fetching profile batch at offset {offset}: {err}")
            break
        offset += limit
        sleep(0.5)

    print(f"Total profile records fetched: {len(all_profiles)}")

except Exception as err:
    print(f"Failed during profile data retrieval: {err}")
    exit(1)

# Write container profiles output
try:
    if PROFILE_OUTPUT_FORMAT == "json":
        with open(PROFILE_OUTPUT_FILE, "w") as f:
            json.dump(all_profiles, f, indent=4)
    else:
        with open(PROFILE_OUTPUT_FILE, "w", newline='') as f:
            writer = csv.DictWriter(f, fieldnames=PROFILE_FIELDS)
            writer.writeheader()
            writer.writerows(all_profiles)

    print(f"Profile data written to {PROFILE_OUTPUT_FILE}")

except Exception as err:
    print(f"Failed to write profile output file: {err}")
    exit(1)

# Fetch incidents
all_incidents = []
offset = 0
limit = 50

try:
    print("Fetching initial batch of incidents...")
    res = cwp_session.request(
        'GET',
        f'/api/v1/audits/incidents?acknowledged=false&category=suspiciousBinary&from={from_date}&limit={limit}&offset={offset}&to={to_date}&type=host'
    )
    total_count = int(res.headers.get("Total-Count", 0))
    print(f"Total incidents to fetch: {total_count}")

    while offset < total_count:
        print(f"Fetching incident records {offset + 1} to {offset + limit}...")
        try:
            res = cwp_session.request(
                'GET',
                f'/api/v1/audits/incidents?acknowledged=false&category=suspiciousBinary&from={from_date}&limit={limit}&offset={offset}&to={to_date}&type=host'
            )
            res.raise_for_status()
            batch = res.json()
            for incident in batch:
                all_incidents.append(extract_incident_fields(incident))
        except Exception as err:
            print(f"Error fetching incident batch at offset {offset}: {err}")
            break
        offset += limit
        sleep(0.5)

    print(f"Total incident records fetched: {len(all_incidents)}")

except Exception as err:
    print(f"Failed during incident data retrieval: {err}")
    exit(1)

# Write incidents output
try:
    if INCIDENT_OUTPUT_FORMAT == "json":
        with open(INCIDENT_OUTPUT_FILE, "w") as f:
            json.dump(all_incidents, f, indent=4)
    else:
        with open(INCIDENT_OUTPUT_FILE, "w", newline='') as f:
            writer = csv.DictWriter(f, fieldnames=INCIDENT_FIELDS)
            writer.writeheader()
            writer.writerows(all_incidents)

    print(f"Incident data written to {INCIDENT_OUTPUT_FILE}")

except Exception as err:
    print(f"Failed to write incident output file: {err}")
    exit(1)

# Compare MD5 values and output matching profiles with additional incident fields
try:
    incident_md5s = set(incident['md5'] for incident in all_incidents if incident['md5'])
    print(f"Total unique MD5s found in incidents: {len(incident_md5s)}")

    matched_profiles = []
    matches_found = 0

    for profile in all_profiles:
        profile_md5 = profile.get('processes.static.md5')
        if profile_md5 in incident_md5s:
            matching_incidents = [inc for inc in all_incidents if inc['md5'] == profile_md5]
            for incident in matching_incidents:
                matched = profile.copy()
                # Add incident fields with prefix
                matched['incident._id'] = incident['_id']
                matched['incident.hostname'] = incident['hostname']
                matched['incident.fqdn'] = incident['fqdn']
                matched['incident.containerName'] = incident['containerName']
                matched['incident.containerID'] = incident['containerID']
                matched['incident.imageName'] = incident['imageName']
                matched['incident.imageID'] = incident['imageID']
                matched['incident.profileID'] = incident['profileID']
                matched_profiles.append(matched)
                matches_found += 1
            print(f"Matched profile MD5: {profile_md5} with {len(matching_incidents)} incidents.")

    if matched_profiles:
        with open(MATCHED_OUTPUT_FILE, "w", newline='') as f:
            writer = csv.DictWriter(f, fieldnames=MATCHED_FIELDS)
            writer.writeheader()
            writer.writerows(matched_profiles)
        print(f"Found {matches_found} matched profiles. Data written to {MATCHED_OUTPUT_FILE}")
    else:
        print("No profiles found with matching MD5s. No matched file written.")

except Exception as err:
    print(f"Failed to compare MD5s or write matched profile data: {err}")
    exit(1)
