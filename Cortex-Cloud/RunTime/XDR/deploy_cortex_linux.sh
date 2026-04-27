#!/bin/bash
# ==============================================================================
# Cortex XDR / XSIAM Linux Standalone Agent Deployment Script
# ==============================================================================
# Retrieves the latest version, creates a new standalone distribution, securely 
# downloads the tar.gz, extracts it, configures cortex.conf, and installs.
#
# ENVIRONMENT VARIABLES:
#   CORTEX_FQDN         (Required) - API FQDN (e.g., api-xxxx.xdr.us.paloaltonetworks.com)
#   CORTEX_API_KEY_ID   (Required) - Advanced API Key ID
#   CORTEX_API_KEY      (Required) - Advanced API Key
#   DEBUG               (Optional) - Set to "true" for verbose debug logging
# ==============================================================================

set -euo pipefail

# ==============================================================================
# LOGGING FRAMEWORK
# ==============================================================================
DEBUG_MODE="${DEBUG:-false}"

log() {
    local level="$1"
    shift
    printf "[%s] [%-5s] %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$level" "$*"
}

log_info()  { log "INFO"  "$*"; }
log_warn()  { log "WARN"  "$*" >&2; }
log_error() { log "ERROR" "$*" >&2; }
log_debug() {
    if [[ "$DEBUG_MODE" == "true" || "$DEBUG_MODE" == "True" || "$DEBUG_MODE" == "TRUE" || "$DEBUG_MODE" == "1" ]]; then
        log "DEBUG" "$*"
    fi
}
die() { log_error "$*"; exit 1; }

# ==============================================================================
# HELPER FUNCTIONS & CLEANUP
# ==============================================================================
cleanup() {
    log_debug "Executing cleanup routine..."
    if [[ -n "${DOWNLOAD_DEST:-}" && -f "$DOWNLOAD_DEST" ]]; then
        log_info "Removing downloaded archive: $DOWNLOAD_DEST"
        rm -f "$DOWNLOAD_DEST"
    fi
    if [[ -n "${EXTRACT_DIR:-}" && -d "$EXTRACT_DIR" ]]; then
        log_info "Removing temporary extraction directory: $EXTRACT_DIR"
        rm -rf "$EXTRACT_DIR"
    fi
}
trap cleanup EXIT

check_dependencies() {
    log_debug "Checking required dependencies..."
    command -v curl >/dev/null 2>&1 || die "Dependency 'curl' is missing."
    command -v python3 >/dev/null 2>&1 || die "Dependency 'python3' is missing."
    command -v tar >/dev/null 2>&1 || die "Dependency 'tar' is missing."
    command -v gzip >/dev/null 2>&1 || die "Dependency 'gzip' is missing."
    log_debug "Dependencies verified."
}

curl_with_retry() {
    local max_attempts=3
    local attempt=1
    local delay=5
    local result

    while [ $attempt -le $max_attempts ]; do
        log_debug "Executing API request (Attempt $attempt/$max_attempts)..."
        set +e
        result=$(curl -sSLf "$@")
        local exit_code=$?
        set -e

        if [ $exit_code -eq 0 ]; then
            log_debug "API request successful."
            echo "$result"
            return 0
        fi

        log_warn "Network request failed with cURL exit code $exit_code. (Attempt $attempt/$max_attempts)"
        if [ $attempt -lt $max_attempts ]; then
            log_info "Retrying network request in $delay seconds..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done

    die "Exhausted all $max_attempts retry attempts for network request."
}

# ==============================================================================
# CONFIGURATION & VALIDATION
# ==============================================================================
log_info "Starting Cortex XDR/XSIAM Linux Deployment Script..."

# --- ROOT PRIVILEGE CHECK ---
if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root to install the agent. Please execute it using: sudo -E $0"
fi

if [[ -z "${CORTEX_FQDN:-}" || -z "${CORTEX_API_KEY_ID:-}" || -z "${CORTEX_API_KEY:-}" ]]; then
    die "Missing required environment variables (CORTEX_FQDN, CORTEX_API_KEY_ID, CORTEX_API_KEY)."
fi

PACKAGE_NAME="${CORTEX_PACKAGE_NAME:-Linux_Standalone_Auto_Deploy_$(date +%s)}"
BASE_URL="https://${CORTEX_FQDN}/public_api/v1/distributions"
DOWNLOAD_DEST="/tmp/cortex_installer_$$.tar.gz"
EXTRACT_DIR="/tmp/cortex_extract_$$"

check_dependencies

# ------------------------------------------------------------------------------
# 1. Dynamically Detect OS, Architecture & Package Manager
# ------------------------------------------------------------------------------
log_info "Phase 1: Environment Detection"

OS_PRETTY_NAME="Unknown Linux OS"
if [[ -f /etc/os-release ]]; then
    OS_PRETTY_NAME=$(grep ^PRETTY_NAME= /etc/os-release | cut -d= -f2 | tr -d '"')
fi

ARCH=$(uname -m)
FORMAT_PREFIX=""

if [[ "$ARCH" == "aarch64" ]]; then
    FORMAT_PREFIX="aarch64_"
elif [[ "$ARCH" != "x86_64" ]]; then
    log_warn "Unrecognized architecture '$ARCH'. Defaulting to x86_64."
fi

if command -v dpkg >/dev/null 2>&1 || [[ -f /etc/debian_version ]]; then
    BASE_FORMAT="deb"
elif command -v rpm >/dev/null 2>&1 || [[ -f /etc/redhat-release ]]; then
    BASE_FORMAT="rpm"
else
    BASE_FORMAT="sh"
fi

INSTALLER_FORMAT="${FORMAT_PREFIX}${BASE_FORMAT}"

log_info "Host OS: $OS_PRETTY_NAME"
log_info "Host Architecture: $ARCH"
log_info "Target Package Format: $BASE_FORMAT"
log_info "Target Cortex API Package Type: $INSTALLER_FORMAT"

# ------------------------------------------------------------------------------
# 2. Get the Latest Linux Agent Version
# ------------------------------------------------------------------------------
log_info "Phase 2: Fetching Latest Agent Version"

VERSIONS_RESP=$(curl_with_retry -X POST "${BASE_URL}/get_versions" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
    -H "Authorization: ${CORTEX_API_KEY}" \
    -d '{ "request_data": {} }')

LATEST_VERSION=$(echo "$VERSIONS_RESP" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    linux_versions = data.get("reply", {}).get("linux", [])
    if not linux_versions:
        print("")
    else:
        latest = sorted(linux_versions, key=lambda x: [int(i) for i in x.split(".")])[-1]
        print(latest)
except Exception:
    print("")
')

if [[ -z "$LATEST_VERSION" ]]; then
    die "Failed to parse the latest Linux version. Raw response: $VERSIONS_RESP"
fi

log_info "Successfully identified target version: $LATEST_VERSION"

# ------------------------------------------------------------------------------
# 3. Create New Distribution
# ------------------------------------------------------------------------------
log_info "Phase 3: Creating Standalone Distribution Package"
log_debug "Requested Distribution Name: $PACKAGE_NAME"

JSON_PAYLOAD=$(printf '{ "request_data": { "name": "%s", "platform": "linux", "package_type": "standalone", "agent_version": "%s" } }' "$PACKAGE_NAME" "$LATEST_VERSION")

CREATE_RESP=$(curl_with_retry -X POST "${BASE_URL}/create" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
    -H "Authorization: ${CORTEX_API_KEY}" \
    -d "$JSON_PAYLOAD")

DIST_ID=$(echo "$CREATE_RESP" | python3 -c 'import sys, json; data=json.load(sys.stdin); print(data.get("reply", {}).get("distribution_id", ""))' 2>/dev/null)

if [[ -z "$DIST_ID" ]]; then
    die "Failed to parse distribution_id. Raw response: $CREATE_RESP"
fi

log_info "Distribution request submitted. Distribution ID: $DIST_ID"

# ------------------------------------------------------------------------------
# 4. Wait for Distribution to be Ready (Polling)
# ------------------------------------------------------------------------------
log_info "Phase 4: Waiting for Cortex to compile the distribution..."

MAX_WAIT_LOOPS=10
WAIT_SLEEP=30
IS_READY=false

STATUS_PAYLOAD=$(printf '{ "request_data": { "distribution_id": "%s" } }' "$DIST_ID")

for ((i=1; i<=MAX_WAIT_LOOPS; i++)); do
    log_debug "Polling distribution status (Attempt $i/$MAX_WAIT_LOOPS)..."
    STATUS_RESP=$(curl_with_retry -X POST "${BASE_URL}/get_status" \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
        -H "Authorization: ${CORTEX_API_KEY}" \
        -d "$STATUS_PAYLOAD")
    
    STATUS=$(echo "$STATUS_RESP" | python3 -c 'import sys, json; data=json.load(sys.stdin); print(data.get("reply", {}).get("status", ""))' 2>/dev/null | tr '[:upper:]' '[:lower:]')
    
    if [[ "$STATUS" == "completed" || "$STATUS" == "success" || "$STATUS" == "created" || "$STATUS" == "done" ]]; then
        IS_READY=true
        log_info "Distribution compilation is complete and ready."
        break
    elif [[ "$STATUS" == "failed" || "$STATUS" == "error" ]]; then
        die "Distribution compilation failed on Cortex backend. Status returned: $STATUS"
    else
        log_info "Status is '$STATUS'. Waiting $WAIT_SLEEP seconds..."
        sleep $WAIT_SLEEP
    fi
done

if [[ "$IS_READY" == false ]]; then
    die "Timed out waiting for the distribution to compile after 5 minutes."
fi

# ------------------------------------------------------------------------------
# 5. Get Distribution Download URL
# ------------------------------------------------------------------------------
log_info "Phase 5: Fetching Download URL"
log_debug "Requesting URL for format: $INSTALLER_FORMAT"

URL_PAYLOAD=$(printf '{ "request_data": { "distribution_id": "%s", "package_type": "%s" } }' "$DIST_ID" "$INSTALLER_FORMAT")

URL_RESP=$(curl_with_retry -X POST "${BASE_URL}/get_dist_url" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
    -H "Authorization: ${CORTEX_API_KEY}" \
    -d "$URL_PAYLOAD")

DOWNLOAD_URL=$(echo "$URL_RESP" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get("reply", {}).get("distribution_url", "").strip())
except Exception:
    print("")
')

if [[ -z "$DOWNLOAD_URL" ]]; then
    die "Failed to parse download URL. Raw response: $URL_RESP"
fi

log_info "Download URL successfully retrieved."
log_debug "Secure URL: $DOWNLOAD_URL"

# ------------------------------------------------------------------------------
# 6. Download and Validate the Installer
# ------------------------------------------------------------------------------
log_info "Phase 6: Downloading Agent Installer Archive"
log_info "Downloading archive to: $DOWNLOAD_DEST"

log_debug "Attempting secure download WITH Cortex API authentication headers..."
set +e
curl -sSLf -H "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" -H "Authorization: ${CORTEX_API_KEY}" -o "$DOWNLOAD_DEST" "$DOWNLOAD_URL"
DL_EXIT_CODE=$?
set -e

if [ $DL_EXIT_CODE -ne 0 ]; then
    log_warn "Download with headers failed (Exit code: $DL_EXIT_CODE). Retrying without headers..."
    curl_with_retry -o "$DOWNLOAD_DEST" "$DOWNLOAD_URL"
else
    log_debug "Download successful on first attempt."
fi

if [[ ! -f "$DOWNLOAD_DEST" ]]; then
    die "Failed to write downloaded archive to disk."
fi

FILE_SIZE=$(wc -c < "$DOWNLOAD_DEST" | awk '{print $1}')
log_debug "File size: $FILE_SIZE bytes."

if ! gzip -t "$DOWNLOAD_DEST" 2>/dev/null; then
    log_error "The downloaded file is NOT a valid gzip archive."
    log_debug "Preview of downloaded file contents:"
    head -n 10 "$DOWNLOAD_DEST" >&2 || true
    die "Installation aborted due to corrupted or invalid download payload."
fi

log_info "Archive integrity validated successfully."

# ------------------------------------------------------------------------------
# 7. Extract, Configure, and Execute the Installer
# ------------------------------------------------------------------------------
log_info "Phase 7: Extracting and Configuring Agent"

mkdir -p "$EXTRACT_DIR"
log_info "Extracting archive to: $EXTRACT_DIR"
tar -xzf "$DOWNLOAD_DEST" -C "$EXTRACT_DIR"

# 7a. Handle cortex.conf (this answers your question)
CONF_FILE=$(find "$EXTRACT_DIR" -type f -name "cortex.conf" | head -n 1)

if [[ -n "$CONF_FILE" ]]; then
    log_info "Configuration file (cortex.conf) found. Applying to /etc/panw/..."
    mkdir -p /etc/panw
    cp "$CONF_FILE" /etc/panw/cortex.conf
    chmod 644 /etc/panw/cortex.conf
    log_debug "Configuration applied successfully."
else
    log_warn "cortex.conf was not found in the extracted archive. Agent might not register automatically."
fi

# 7b. Locate the installer payload
INSTALLER_FILE=$(find "$EXTRACT_DIR" -type f \( -name "*.rpm" -o -name "*.deb" -o -name "*.sh" \) | head -n 1)

if [[ -z "$INSTALLER_FILE" ]]; then
    die "Could not locate an .rpm, .deb, or .sh file inside the extracted archive."
fi

log_info "Successfully located installer payload: $(basename "$INSTALLER_FILE")"
log_info "Applying execution permissions..."
chmod +x "$INSTALLER_FILE"

# 7c. Execute installation
log_info "Phase 8: Executing Installation"
if [[ "$BASE_FORMAT" == "deb" ]]; then
    log_debug "Triggering: dpkg -i $INSTALLER_FILE"
    dpkg -i "$INSTALLER_FILE"
elif [[ "$BASE_FORMAT" == "rpm" ]]; then
    log_debug "Triggering: rpm -ivh $INSTALLER_FILE"
    rpm -ivh "$INSTALLER_FILE"
else
    log_debug "Triggering: bash $INSTALLER_FILE"
    bash "$INSTALLER_FILE"
fi

log_info "Cortex XDR/XSIAM Linux Agent deployment sequence completed successfully."
exit 0