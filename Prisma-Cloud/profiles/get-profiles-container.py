import csv
import json
import logging
import os
from pcpi import session_loader
from time import sleep

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Output format: "csv" or "json"
OUTPUT_FORMAT = 'csv'
OUTPUT_FILE = f"container_profiles_output.{OUTPUT_FORMAT}"

# Target fields to extract
TARGET_FIELDS = [
    'state', 'learnedStartup', '_id', 'hash', 'image', 'os', 'archived',
    'entrypoint', 'infra', 'processes.static.path', 'processes.static.ppath',
    'processes.static.md5', 'imageID', 'namespace', 'cluster', 'accountIDs'
]

# Utility to safely extract nested fields
def get_nested(data, path):
    keys = path.split('.')
    for key in keys:
        if isinstance(data, list):
            data = data[0] if data else {}
        data = data.get(key, {})
    return data if not isinstance(data, dict) else ""

def extract_fields(profile):
    flat = {}
    for field in TARGET_FIELDS:
        flat[field] = get_nested(profile, field)
    # accountIDs may be a list; join if needed
    if isinstance(flat.get("accountIDs"), list):
        flat["accountIDs"] = ",".join(flat["accountIDs"])
    return flat

# Load Session
try:
    logging.info("Loading session...")
    session_managers = session_loader.load_config()
    session_man = session_managers[0]
    cwp_session = session_man.create_cwp_session()
except Exception as e:
    logging.error(f"Failed to load or authenticate session: {e}")
    exit(1)

# Main logic to paginate and fetch all entries
all_profiles = []
limit = 100  # reasonable batch size
offset = 0

try:
    # First call to get total count
    logging.info("Fetching initial batch to get total count...")
    res = cwp_session.request(
        'GET',
        f'/api/v1/profiles/container?limit={limit}&offset={offset}&project=Central+Console&reverse=false'
    )
    total_count = int(res.headers.get("Total-Count", 0))
    logging.info(f"Total profiles to fetch: {total_count}")

    while offset < total_count:
        logging.info(f"Fetching records {offset + 1} to {offset + limit}...")
        try:
            res = cwp_session.request(
                'GET',
                f'/api/v1/profiles/container?limit={limit}&offset={offset}&project=Central+Console&reverse=false'
            )
            res.raise_for_status()
            batch = res.json()
            for profile in batch:
                all_profiles.append(extract_fields(profile))
        except Exception as err:
            logging.error(f"Error fetching batch at offset {offset}: {err}")
            break
        offset += limit
        sleep(0.5)  # be polite to the API

    logging.info(f"Total records fetched: {len(all_profiles)}")

except Exception as err:
    logging.error(f"Failed during data retrieval: {err}")
    exit(1)

# Output the result
try:
    if OUTPUT_FORMAT == "json":
        with open(OUTPUT_FILE, "w") as f:
            json.dump(all_profiles, f, indent=4)
    else:
        with open(OUTPUT_FILE, "w", newline='') as f:
            writer = csv.DictWriter(f, fieldnames=TARGET_FIELDS)
            writer.writeheader()
            writer.writerows(all_profiles)

    logging.info(f"Data written to {OUTPUT_FILE}")

except Exception as err:
    logging.error(f"Failed to write output file: {err}")
    exit(1)
