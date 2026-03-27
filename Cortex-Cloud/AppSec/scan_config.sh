#!/usr/bin/env bash
# Enforce error handling, omit 'u' to prevent macOS Bash 3.2 empty array bugs
set -eo pipefail

# ==========================================
# Configuration & Global Variables
# ==========================================
STATE_FILE=".cortex_checkpoint.log"
TMP_RESULTS_FILE=".cortex_results.tmp"
BATCH_SIZE=20
MAX_RETRIES=5

# Modern CLI Colors (Cortex Agentic Green Theme)
DIM='\033[2m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
C_GREEN='\033[38;5;46m'   
S_GREEN='\033[38;5;114m'  
YELLOW='\033[38;5;228m'   
RED='\033[38;5;196m'      
NC='\033[0m'              

# Initialize stats
TOTAL_FETCHED=0
TOTAL_TARGETED=0
TOTAL_PENDING=0
SUCCESS_COUNT=0
FAIL_COUNT=0
RETRY_COUNT=0

# ==========================================
# UI Layout & Animations
# ==========================================
print_intro() {
    clear
    local logo=(
        "${C_GREEN}  ____ ___  ____ _____ _______  __   ____ _     ___  _   _ ____  ${NC}"
        "${C_GREEN} / ___/ _ \\|  _ \\_   _| ____\\ \\/ /  / ___| |   / _ \\| | | |  _ \\ ${NC}"
        "${C_GREEN}| |  | | | | |_) || | |  _|  \\  /  | |   | |  | | | | | | | | | |${NC}"
        "${C_GREEN}| |__| |_| |  _ < | | | |___ /  \\  | |___| |__| |_| | |_| | |_| |${NC}"
        "${C_GREEN} \\____\\___/|_| \\_\\|_| |_____/_/\\_\\  \\____|_____\\___/ \\___/|____/ ${NC}"
    )

    echo ""
    for line in "${logo[@]}"; do
        echo -e "$line"
        sleep 0.05
    done
    echo ""

    echo -e "${C_GREEN}╭────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${C_GREEN}│${NC}  ${BOLD}Operation: AppSec Repository Scan Configurations${NC}               ${C_GREEN}│${NC}"
    echo -e "${C_GREEN}╰────────────────────────────────────────────────────────────────────────╯${NC}\n"

    echo -e "${BOLD}Cortex Cloud Platform APIs${NC}"
    echo -e "${DIM}› APIs › ASPM, CICD and Application Security APIs › Repositories${NC}"
    echo -e "${DIM}›${NC} ${UNDERLINE}Get / Update repository scan configurations dynamically${NC}\n"
}

ask_prompt() {
    local prompt_text=$1
    local default_hint=$2
    local var_name=$3
    local is_secret=${4:-false}

    echo -e "${DIM}╭────────────────────────────────────────────────────────────────────────╮${NC}"
    if [[ "$is_secret" == "true" ]]; then
        echo -ne "${DIM}│${NC} ${C_GREEN}>${NC} ${prompt_text} ${DIM}${default_hint}${NC} \n${DIM}│${NC}   "
        read -s "$var_name"
        echo ""
    else
        echo -ne "${DIM}│${NC} ${C_GREEN}>${NC} ${prompt_text} ${DIM}${default_hint}${NC} \n${DIM}│${NC}   "
        read -r "$var_name"
    fi
    echo -e "${DIM}╰────────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e "${DIM}~/AppSec/Workspace             cortex-exec (api-patch)             v2.2.0${NC}\n"
}

log_info()    { echo -e "${C_GREEN}>${NC} ${1}" >&2; }
log_success() { echo -e "${C_GREEN}✓${NC} ${1}" >&2; }
log_warn()    { echo -e "${YELLOW}△${NC} ${1}" >&2; }
log_err()     { echo -e "${RED}✕${NC} ${1}" >&2; }
log_debug()   { if [[ "${DEBUG_MODE:-false}" == "true" ]]; then echo -e "${DIM}  [DEBUG] ${1}${NC}" >&2; fi; }

animate_wait() {
    local seconds=$1
    local msg=$2
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    local end=$((SECONDS + seconds))
    
    while [ $SECONDS -lt $end ]; do
        local temp=${spinstr#?}
        printf "\r${C_GREEN}%c${NC} %s" "$spinstr" "$msg" >&2
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r\033[K" >&2
}

# ==========================================
# Core API Function
# ==========================================
execute_with_retry() {
    local url=$1
    local method=$2
    local payload=$3
    local attempt=1
    local backoff=2
    local http_status=0

    while (( attempt <= MAX_RETRIES )); do
        log_debug "Making $method request to $url (Attempt $attempt/$MAX_RETRIES)"
        
        if [[ "$method" == "GET" ]]; then
            RESPONSE=$(curl -s -w "\n%{http_code}" --location --request GET "$url" \
                --header "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
                --header "Authorization: ${CORTEX_API_KEY}" \
                --header "Content-Type: application/json")
        else
            RESPONSE=$(curl -s -w "\n%{http_code}" --location --request PUT "$url" \
                --header "x-xdr-auth-id: ${CORTEX_API_KEY_ID}" \
                --header "Authorization: ${CORTEX_API_KEY}" \
                --header "Content-Type: application/json" \
                --data "$payload")
        fi

        local body=$(echo "$RESPONSE" | sed '$ d')
        http_status=$(echo "$RESPONSE" | tail -n 1)

        if [[ "$http_status" -eq 401 || "$http_status" -eq 403 ]]; then
            echo "" >&2
            log_err "Authentication failed (HTTP $http_status). Verify API Key and ID."
            exit 1
        fi

        if [[ "$http_status" -eq 429 || "$http_status" -ge 500 || "$http_status" -eq 000 ]]; then
            animate_wait $backoff "Rate limit/Server Error ($http_status). Backing off..."
            backoff=$((backoff * 2))
            ((attempt++))
            ((RETRY_COUNT++))
            continue
        fi

        echo "$RESPONSE"
        return 0
    done

    log_err "Max retries ($MAX_RETRIES) reached."
    echo "$RESPONSE"
    return 1
}

# ==========================================
# Phase 1: Interactive Authentication
# ==========================================
print_intro

for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then log_err "Missing: '${cmd}'. Please install."; exit 1; fi
done

[[ -z "${CORTEX_FQDN:-}" ]] && ask_prompt "Enter Cortex FQDN" "[api-real786.xdr.us.paloaltonetworks.com]" CORTEX_FQDN "false"
CORTEX_FQDN=${CORTEX_FQDN:-api-real786.xdr.us.paloaltonetworks.com}

[[ -z "${CORTEX_API_KEY_ID:-}" ]] && ask_prompt "Enter API Key ID (x-xdr-auth-id)" "" CORTEX_API_KEY_ID "false"
[[ -z "${CORTEX_API_KEY:-}" ]] && ask_prompt "Enter API Key (Authorization)" "[Input hidden]" CORTEX_API_KEY "true"

if [[ -z "$CORTEX_API_KEY_ID" ]] || [[ -z "$CORTEX_API_KEY" ]]; then
    log_err "Valid credentials required. Exiting."; exit 1
fi

API_BASE_URL="https://${CORTEX_FQDN}/public_api/appsec/v1"

# ==========================================
# Phase 2: Granular Configuration Builder
# ==========================================
ask_prompt "Output Report Format?" "[json/csv, default: json]" val "false"
if [[ "$val" =~ ^[Cc][Ss][Vv]$ ]]; then REPORT_FORMAT="csv"; else REPORT_FORMAT="json"; fi

echo -e "${BOLD}Repository Source Platform${NC}"
echo -e "  [1] ${C_GREEN}GITHUB${NC} (Default)"
echo -e "  [2] GITHUB_ENTERPRISE"
echo -e "  [3] GITLAB"
echo -e "  [4] GITLAB_SELF_MANAGED"
echo -e "  [5] BITBUCKET"
echo -e "  [6] BITBUCKET_DATACENTER"
echo -e "  [7] AZURE_REPOS"
echo -e "  [8] AWS_CODE_COMMIT"
ask_prompt "Select target source" "[1-8, default: 1]" SOURCE_SEL "false"

case "$SOURCE_SEL" in
    2) REPO_SOURCE="GITHUB_ENTERPRISE" ;;
    3) REPO_SOURCE="GITLAB" ;;
    4) REPO_SOURCE="GITLAB_SELF_MANAGED" ;;
    5) REPO_SOURCE="BITBUCKET" ;;
    6) REPO_SOURCE="BITBUCKET_DATACENTER" ;;
    7) REPO_SOURCE="AZURE_REPOS" ;;
    8) REPO_SOURCE="AWS_CODE_COMMIT" ;;
    *) REPO_SOURCE="GITHUB" ;;
esac

echo -e "${BOLD}Granular Configuration Settings${NC}"
echo -e "${DIM}Select action for each feature: [e]nable, [d]isable, or [s]kip (leave current setting as-is).${NC}"

ask_prompt "IAC Scanner?" "[e/d/S]" ACT_IAC "false"
ask_prompt "SCA Scanner?" "[e/d/S]" ACT_SCA "false"
ask_prompt "SECRETS Scanner?" "[e/d/S]" ACT_SEC "false"
ask_prompt "Deep Git History Scan?" "[e/d/S]" ACT_GIT "false"
ask_prompt "Pipeline PR Scanning?" "[e/d/S]" ACT_PR "false"

# Build the dynamic jq filter string based on user inputs
JQ_PATCH=". | del(.scanners.SECRETS.scanOptions.validateSecrets?)"

[[ "$ACT_IAC" =~ ^[Ee]$ ]] && JQ_PATCH+=" | .scanners.IAC.isEnabled = true"
[[ "$ACT_IAC" =~ ^[Dd]$ ]] && JQ_PATCH+=" | .scanners.IAC.isEnabled = false"

[[ "$ACT_SCA" =~ ^[Ee]$ ]] && JQ_PATCH+=" | .scanners.SCA.isEnabled = true"
[[ "$ACT_SCA" =~ ^[Dd]$ ]] && JQ_PATCH+=" | .scanners.SCA.isEnabled = false"

[[ "$ACT_SEC" =~ ^[Ee]$ ]] && JQ_PATCH+=" | .scanners.SECRETS.isEnabled = true"
[[ "$ACT_SEC" =~ ^[Dd]$ ]] && JQ_PATCH+=" | .scanners.SECRETS.isEnabled = false"

[[ "$ACT_GIT" =~ ^[Ee]$ ]] && JQ_PATCH+=" | (.scanners.SECRETS.scanOptions //= {}) | .scanners.SECRETS.scanOptions.gitHistory = true"
[[ "$ACT_GIT" =~ ^[Dd]$ ]] && JQ_PATCH+=" | (.scanners.SECRETS.scanOptions //= {}) | .scanners.SECRETS.scanOptions.gitHistory = false"

[[ "$ACT_PR" =~ ^[Ee]$ ]] && JQ_PATCH+=" | (.prScanning //= {}) | .prScanning.isEnabled = true"
[[ "$ACT_PR" =~ ^[Dd]$ ]] && JQ_PATCH+=" | (.prScanning //= {}) | .prScanning.isEnabled = false"

> "$TMP_RESULTS_FILE" # Clear temp results

# ==========================================
# Phase 3: Checkpoint Management
# ==========================================
PROCESSED_IDS=()
if [[ -f "$STATE_FILE" ]]; then
    STATE_COUNT=$(wc -l < "$STATE_FILE" | awk '{print $1}')
    if [[ "$STATE_COUNT" -gt 0 ]]; then
        ask_prompt "Found checkpoint with $STATE_COUNT processed repos. [R]esume or [S]tart Fresh?" "[R/s, default: R]" CHECKPOINT_ACTION "false"
        if [[ "$CHECKPOINT_ACTION" =~ ^[Ss]$ ]]; then
            log_info "Starting fresh. Clearing previous checkpoint."
            rm -f "$STATE_FILE"
        else
            log_info "Resuming from local checkpoint: $STATE_FILE"
            while IFS= read -r id; do [[ -n "$id" ]] && PROCESSED_IDS+=("$id"); done < "$STATE_FILE"
        fi
    fi
fi

# ==========================================
# Phase 4: Fetch & Pattern Targeting
# ==========================================
animate_wait 2 "Fetching ${REPO_SOURCE} repository list from Cortex Cloud..."

# Using the dynamically selected REPO_SOURCE variable
FETCH_RESP=$(execute_with_retry "${API_BASE_URL}/repositories?source=${REPO_SOURCE}" "GET" "")
FETCH_STATUS=$(echo "$FETCH_RESP" | tail -n 1)
FETCH_BODY=$(echo "$FETCH_RESP" | sed '$ d')

if [[ "$FETCH_STATUS" -ne 200 ]]; then
    echo "" >&2; log_err "Data retrieval failed. HTTP Status: $FETCH_STATUS"; exit 1
fi

echo -e "${BOLD}Repository Targeting Strategy${NC}"
echo -e "  [1] ${C_GREEN}Global${NC}  (Target all repositories)"
echo -e "  [2] ${C_GREEN}Include${NC} (Regex match on repository name)"
echo -e "  [3] ${C_GREEN}Exclude${NC} (Regex match on repository name)"
ask_prompt "Select strategy" "[1/2/3, default: 1]" TARGET_STRAT "false"

TARGET_REGEX=""
if [[ "$TARGET_STRAT" == "2" ]]; then
    ask_prompt "Enter Include Regex pattern" "[e.g., ^frontend- ]" TARGET_REGEX "false"
elif [[ "$TARGET_STRAT" == "3" ]]; then
    ask_prompt "Enter Exclude Regex pattern" "[e.g., -legacy$ ]" TARGET_REGEX "false"
fi

TARGETED_IDS=()
while IFS=',' read -r id name; do
    [[ -z "$id" ]] && continue
    ((TOTAL_FETCHED++))
    
    if [[ "$TARGET_STRAT" == "2" && -n "$TARGET_REGEX" ]]; then
        if [[ ! "$name" =~ $TARGET_REGEX ]]; then continue; fi
    elif [[ "$TARGET_STRAT" == "3" && -n "$TARGET_REGEX" ]]; then
        if [[ "$name" =~ $TARGET_REGEX ]]; then continue; fi
    fi
    
    TARGETED_IDS+=("$id")
done <<< "$(echo "$FETCH_BODY" | jq -r '.[] | "\(.id),\(.name)"' 2>/dev/null || true)"

TOTAL_TARGETED=${#TARGETED_IDS[@]}

PENDING_IDS=()
for id in "${TARGETED_IDS[@]}"; do
    if [[ ! " ${PROCESSED_IDS[*]} " =~ " ${id} " ]]; then PENDING_IDS+=("$id"); fi
done
TOTAL_PENDING=${#PENDING_IDS[@]}

echo -e "\n${BOLD}Targeting Plan Overview${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
echo -e "Target Source        : ${C_GREEN}${REPO_SOURCE}${NC}"
echo -e "Total Repos in Cloud : ${DIM}$TOTAL_FETCHED${NC}"
echo -e "Matched by Filter    : ${C_GREEN}$TOTAL_TARGETED${NC}"
echo -e "Already Processed    : ${S_GREEN}${#PROCESSED_IDS[@]}${NC}"
echo -e "Pending Processing   : ${BOLD}$TOTAL_PENDING${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}\n"

if [[ "$TOTAL_PENDING" -eq 0 ]]; then
    log_success "No pending repositories match the criteria."; exit 0
fi

ask_prompt "Execute surgical patch for $TOTAL_PENDING repositories?" "[y/N]" val "false"
if [[ ! "$val" =~ ^[Yy]$ ]]; then log_warn "Execution cancelled by user."; exit 0; fi

# ==========================================
# Phase 5: Dynamic GET ➔ PATCH ➔ PUT Execution
# ==========================================
for (( i=0; i<TOTAL_PENDING; i+=BATCH_SIZE )); do
    BATCH=("${PENDING_IDS[@]:i:BATCH_SIZE}")
    BATCH_NUM=$(( (i / BATCH_SIZE) + 1 ))
    TOTAL_BATCHES=$(( (TOTAL_PENDING + BATCH_SIZE - 1) / BATCH_SIZE ))
    
    echo -e "\n${C_GREEN}>${NC} Processing Batch ${BATCH_NUM}/${TOTAL_BATCHES} (${#BATCH[@]} assets)"

    for ASSET_ID in "${BATCH[@]}"; do
        printf "  ${DIM}Processing %-50s${NC}" "${ASSET_ID:0:15}..." >&2
        
        # 1. GET Current Configuration
        CONFIG_URL="${API_BASE_URL}/repositories/${ASSET_ID}/scan-configuration"
        GET_RESP=$(execute_with_retry "$CONFIG_URL" "GET" "")
        GET_STATUS=$(echo "$GET_RESP" | tail -n 1)
        CURRENT_JSON=$(echo "$GET_RESP" | sed '$ d')

        if [[ "$GET_STATUS" -ne 200 ]]; then
            printf "\r  ${DIM}Processing %-50s${NC} [${RED}GET FAILED${NC}] (HTTP %s)\n" "${ASSET_ID:0:15}..." "$GET_STATUS" >&2
            ((FAIL_COUNT++))
            echo "$ASSET_ID,GET_FAILED,$GET_STATUS" >> "$TMP_RESULTS_FILE"
            continue
        fi

        # 2. PATCH Configuration Dynamically via jq
        PATCHED_JSON=$(echo "$CURRENT_JSON" | jq -c "$JQ_PATCH" 2>/dev/null || true)
        
        if [[ -z "$PATCHED_JSON" ]]; then
            printf "\r  ${DIM}Processing %-50s${NC} [${RED}PATCH FAILED${NC}]\n" "${ASSET_ID:0:15}..." >&2
            ((FAIL_COUNT++))
            echo "$ASSET_ID,JQ_PATCH_ERROR,N/A" >> "$TMP_RESULTS_FILE"
            continue
        fi

        # 3. PUT Updated Configuration
        PUT_RESP=$(execute_with_retry "$CONFIG_URL" "PUT" "$PATCHED_JSON")
        PUT_STATUS=$(echo "$PUT_RESP" | tail -n 1)
        PUT_BODY=$(echo "$PUT_RESP" | sed '$ d')
        
        if [[ "$PUT_STATUS" -eq 200 || "$PUT_STATUS" -eq 204 ]]; then
            printf "\r  ${DIM}Processing %-50s${NC} [${C_GREEN}PATCHED${NC}]\n" "${ASSET_ID:0:15}..." >&2
            ((SUCCESS_COUNT++))
            echo "$ASSET_ID" >> "$STATE_FILE"
            echo "$ASSET_ID,SUCCESS,$PUT_STATUS" >> "$TMP_RESULTS_FILE"
        else
            printf "\r  ${DIM}Processing %-50s${NC} [${RED}PUT FAILED${NC}] (HTTP %s)\n" "${ASSET_ID:0:15}..." "$PUT_STATUS" >&2
            echo -e "    ${RED}↳ API Error: ${PUT_BODY}${NC}" >&2
            ((FAIL_COUNT++))
            echo "$ASSET_ID,PUT_FAILED,$PUT_STATUS" >> "$TMP_RESULTS_FILE"
        fi
    done
    
    if [[ $BATCH_NUM -lt $TOTAL_BATCHES ]]; then
        animate_wait 2 "Regulating API cadence (Rate Limiting)..."
    fi
done

# ==========================================
# Phase 6: Final Reporting
# ==========================================
REPORT_FILE="cortex_appsec_audit_${REPO_SOURCE}_$(date +%F_%H-%M-%S).$REPORT_FORMAT"

if [[ "$REPORT_FORMAT" == "json" ]]; then
    jq -R -n -c '
      [ inputs | split(",") | {
        "assetId": .[0], "status": .[1], "httpCode": .[2]
      } ]
    ' "$TMP_RESULTS_FILE" > "$REPORT_FILE" || true
else
    echo "AssetID,Status,HTTP_Code" > "$REPORT_FILE"
    cat "$TMP_RESULTS_FILE" >> "$REPORT_FILE"
fi

rm -f "$TMP_RESULTS_FILE"

echo -e "\n${BOLD}Execution Audit Log${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
printf "Target Source  : %-45s\n" "${C_GREEN}${REPO_SOURCE}${NC}"
printf "Targeted Repos : %-45s\n" "${BOLD}$TOTAL_TARGETED${NC}"
printf "Successful     : ${C_GREEN}%-45s${NC}\n" "$SUCCESS_COUNT"
printf "Failed         : ${RED}%-45s${NC}\n" "$FAIL_COUNT"
printf "API Retries    : ${YELLOW}%-45s${NC}\n" "$RETRY_COUNT"
echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
printf "Report Saved   : %-45s\n" "${S_GREEN}$REPORT_FILE${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}\n"

if [[ "$FAIL_COUNT" -eq 0 && "$TOTAL_PENDING" -gt 0 ]]; then
    log_success "Patching complete. Zero errors reported."
else
    log_warn "Finished with exceptions. Review log file or re-run to retry failures."
fi