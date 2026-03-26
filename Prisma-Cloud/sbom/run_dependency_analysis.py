
import json
import os
import logging
from time import sleep
from pcpi import session_loader
from concurrent.futures import ThreadPoolExecutor, TimeoutError

# ==============================================================================
# 📜 --- SCRIPT CONFIGURATION ---
# ==============================================================================

# --- File Configuration ---
RULES_FILE = 'output.json'
DEPENDENCIES_FILE = 'cas_dependencies.json'
MATCHED_IDS_FILE = 'matched_ids.json'
FINAL_OUTPUT_FILE = 'source_locations.json'

# --- API Performance & Stability Configuration ---
API_LIMIT = 50
REQUEST_TIMEOUT = 30  # Timeout in seconds for each API request
API_DELAY = 0.3       # Delay between API calls to avoid rate-limiting


file_path = os.path.join(os.path.expanduser("~"), ".prismacloud", "credentials.json")

# ==============================================================================
# 📝 --- LOGGING CONFIGURATION (REVISED FOR CLEAN OUTPUT) ---
# ==============================================================================

# 1. Configure the logger for our script
script_logger = logging.getLogger(__name__)
script_logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
handler.setFormatter(formatter)
script_logger.addHandler(handler)

# 2. Silence the noisy pcpi library logger by setting its level higher
logging.getLogger('pcpi').setLevel(logging.WARNING)

# ==============================================================================
# 🌐 --- API HELPER FUNCTION ---
# ==============================================================================

def make_api_request(session, method, endpoint, **kwargs):
    """A robust wrapper for making API requests with cross-platform timeouts and JSON validation."""
    try:
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(session.request, method, endpoint, **kwargs)
            res = future.result(timeout=REQUEST_TIMEOUT)

        if res is None:
            raise ConnectionError("API call failed and returned None after internal retries.")
        res.raise_for_status()
        if 'application/json' not in res.headers.get('Content-Type', ''):
            raise ValueError(f"Expected JSON but received '{res.headers.get('Content-Type')}'")
        return res.json()

    except TimeoutError:
        script_logger.error(f"   -> [✖︎] API call to '{endpoint}' timed out after {REQUEST_TIMEOUT} seconds.")
        return None
    except Exception as e:
        script_logger.error(f"   -> [✖︎] API call to '{endpoint}' failed: {e}")
        return None

# ==============================================================================
# ⚙️ --- STEP 1: FETCH ALL CAS DEPENDENCIES ---
# ==============================================================================

def fetch_all_dependencies(session):
    script_logger.info("==========================================================")
    script_logger.info(" [▶︎] STEP 1: Fetching all CAS dependencies...")
    script_logger.info("==========================================================")
    
    all_dependencies, current_page = [], 0
    target_fields = ['id', 'name', 'version', 'origin']

    while True:
        script_logger.info(f" [🔄] Fetching page {current_page}...")
        batch_data = make_api_request(
            session, 'POST', '/bridgecrew/api/v1/sbom/dependencies',
            params={'page': current_page, 'limit': API_LIMIT},
            json={'filters': {}}
        )
        if batch_data is None:
            script_logger.error(" [✖︎] Halting dependency fetch due to API error.")
            return False
        if not batch_data:
            script_logger.info(" [✔︎] Reached the last page. No more dependencies to fetch.")
            break
        for dep in batch_data:
            all_dependencies.append({field: dep.get(field, 'N/A') for field in target_fields})
        script_logger.info(f"    -> Fetched {len(batch_data)} records. Total now: {len(all_dependencies)}")
        current_page += 1
        sleep(API_DELAY)

    try:
        with open(DEPENDENCIES_FILE, "w") as f:
            json.dump(all_dependencies, f, indent=4)
        script_logger.info(f" [💾] SUCCESS: Saved {len(all_dependencies)} dependencies to '{DEPENDENCIES_FILE}'")
        return True
    except Exception as err:
        script_logger.error(f" [✖︎] FAILED to write dependencies to '{DEPENDENCIES_FILE}': {err}")
        return False

# ==============================================================================
# 🔗 --- STEP 2: MATCH RULES TO DEPENDENCIES ---
# ==============================================================================

def match_rules_to_dependencies():
    script_logger.info("==========================================================")
    script_logger.info(" [▶︎] STEP 2: Matching rules to find package IDs...")
    script_logger.info("==========================================================")

    try:
        script_logger.info(f" [📄] Loading rules from '{RULES_FILE}'...")
        with open(RULES_FILE, 'r') as f:
            rules = json.load(f).get('rules', [])
        script_logger.info(f"    -> Loaded {len(rules)} rules.")
        script_logger.info(f" [📄] Loading dependencies from '{DEPENDENCIES_FILE}'...")
        with open(DEPENDENCIES_FILE, 'r') as f:
            dependencies = json.load(f)
        script_logger.info(f"    -> Loaded {len(dependencies)} dependencies.")
        dependency_map = {(dep['name'], dep['version']): dep.get('id') for dep in dependencies if 'name' in dep and 'version' in dep}
        matched_ids = [dependency_map[key] for rule in rules if (key := (rule.get('package'), rule.get('minVersionInclusive'))) in dependency_map]
        script_logger.info(f" [🎯] Found {len(matched_ids)} matches out of {len(rules)} rules.")
        with open(MATCHED_IDS_FILE, 'w') as f:
            json.dump(matched_ids, f, indent=4)
        script_logger.info(f" [💾] SUCCESS: Saved {len(matched_ids)} matched IDs to '{MATCHED_IDS_FILE}'")
        return True
    except FileNotFoundError as e:
        script_logger.error(f" [✖︎] FAILED: Prerequisite file not found: '{e.filename}'.")
        return False
    except Exception as e:
        script_logger.error(f" [✖︎] FAILED during matching: {e}")
        return False

# ==============================================================================
# 📍 --- STEP 3: FETCH SOURCE LOCATIONS FOR MATCHED IDS ---
# ==============================================================================

def fetch_source_locations_for_ids(session):
    script_logger.info("==========================================================")
    script_logger.info(" [▶︎] STEP 3: Fetching source locations for matched IDs...")
    script_logger.info("==========================================================")

    try:
        script_logger.info(f" [📄] Loading matched IDs from '{MATCHED_IDS_FILE}'...")
        with open(MATCHED_IDS_FILE, 'r') as f:
            matched_ids = json.load(f)
        if not matched_ids:
            script_logger.warning(" [🟡] No matched IDs found. Nothing to process.")
            with open(FINAL_OUTPUT_FILE, 'w') as f: json.dump([], f)
            return True
        script_logger.info(f"    -> Found {len(matched_ids)} IDs to process.")
        all_source_locations, total_ids = [], len(matched_ids)
        for i, concrete_id in enumerate(matched_ids):
            script_logger.info(f" [🔄] ({i+1}/{total_ids}) Fetching source for ID: {concrete_id[:50]}...")
            source_data = make_api_request(
                session, 'POST', '/bridgecrew/api/v1/sbom/srcs-by-concreteId',
                json={"concreteId": concrete_id}
            )
            if source_data is not None:
                all_source_locations.append({"matchedId": concrete_id, "sourceLocations": source_data})
            sleep(API_DELAY)
        with open(FINAL_OUTPUT_FILE, 'w') as f:
            json.dump(all_source_locations, f, indent=4)
        script_logger.info(f" [💾] SUCCESS: Saved source locations for {len(all_source_locations)} IDs to '{FINAL_OUTPUT_FILE}'")
        return True
    except FileNotFoundError as e:
        script_logger.error(f" [✖︎] FAILED: Prerequisite file not found: '{e.filename}'.")
        return False
    except Exception as e:
        script_logger.error(f" [✖︎] FAILED while fetching source locations: {e}")
        return False

# ==============================================================================
# 🎉 --- MAIN ORCHESTRATOR ---
# ==============================================================================

if __name__ == "__main__":
    script_logger.info("==========================================================")
    script_logger.info("    DEPENDENCY ANALYSIS AND SOURCE LOCATION WORKFLOW    ")
    script_logger.info("==========================================================")

    try:
        script_logger.info(" [🔐] Authenticating and creating API session...")
        session_managers = session_loader.load_config(file_path=file_path)
        cspm_session = session_managers[0].create_cspm_session()
        script_logger.info("    -> Session created successfully.")
    except Exception as e:
        script_logger.error(f" [✖︎] FATAL: Could not create API session. Check credentials. Error: {e}")
        exit(1)

    if fetch_all_dependencies(cspm_session):
        if match_rules_to_dependencies():
            if fetch_source_locations_for_ids(cspm_session):
                script_logger.info("\n==========================================================")
                script_logger.info(f" [🎉] WORKFLOW COMPLETED SUCCESSFULLY!")
                script_logger.info(f"      Final results are in '{FINAL_OUTPUT_FILE}'")
                script_logger.info("==========================================================")
            else:
                script_logger.error("\n [💥] Workflow failed at Step 3: Fetching source locations.")
        else:
            script_logger.error("\n [💥] Workflow failed at Step 2: Matching rules.")
    else:
        script_logger.error("\n [💥] Workflow failed at Step 1: Fetching dependencies.")
