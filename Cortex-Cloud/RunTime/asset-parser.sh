#!/usr/bin/env bash
# Enforce error handling, omit 'u' to prevent macOS Bash 3.2 empty array bugs
set -eo pipefail

# ==========================================
# Configuration & Global Variables
# ==========================================
VERSION="v2.4.1"
INPUT_FILE=$1

# Modern CLI Colors (Enterprise Agentic Green Theme)
DIM='\033[2m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
C_GREEN='\033[38;5;46m'   
S_GREEN='\033[38;5;114m'  
YELLOW='\033[38;5;228m'   
RED='\033[38;5;196m'      
NC='\033[0m'              

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
        "${S_GREEN}                       P A R S E R                               ${NC}"
    )

    echo ""
    for line in "${logo[@]}"; do
        echo -e "$line"
        sleep 0.05
    done
    echo ""

    echo -e "${C_GREEN}╭────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${C_GREEN}│${NC}  ⚙️  ${BOLD}OPERATION: Vulnerability Issues - Asset Normalization${NC}          ${C_GREEN}│${NC}"
    echo -e "${C_GREEN}╰────────────────────────────────────────────────────────────────────────╯${NC}\n"
}

log_info()    { echo -e "${C_GREEN}>${NC} ${1}" >&2; }
log_success() { echo -e "${C_GREEN}✓${NC} ${1}" >&2; }
log_warn()    { echo -e "${YELLOW}△${NC} ${1}" >&2; }
log_err()     { echo -e "${RED}✕${NC} ${1}" >&2; }

draw_progress() {
    local current=$1
    local total=$2
    local width=40
    local pct=$(( current * 100 / total ))
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "\r${C_GREEN}>${NC} Processing Data: [${C_GREEN}"
    # Draw filled block
    if [[ $filled -gt 0 ]]; then
        printf "%${filled}s" "" | tr ' ' '█'
    fi
    printf "${DIM}"
    # Draw empty block
    if [[ $empty -gt 0 ]]; then
        printf "%${empty}s" "" | tr ' ' '░'
    fi
    # Print percentage and stats
    printf "${NC}] %3d%%  ${DIM}(%d/%d records)${NC}" "$pct" "$current" "$total"
}

# ==========================================
# Boot Sequence & UI Init
# ==========================================
print_intro
log_info "Initializing pre-flight diagnostics..."

# ==========================================
# Pre-Flight Checks & Analysis
# ==========================================
if [[ -z "$INPUT_FILE" ]]; then
    echo -e "\n${RED}[FATAL EXCEPTION] Missing Input Parameter${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}Reason:${NC}  The parser engine requires a target TSV payload to operate."
    echo -e "${BOLD}Action:${NC}  Please provide the path to your data file."
    echo -e "${BOLD}Usage:${NC}   ./$(basename $0) <input_file.tsv>\n"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "\n${RED}[FATAL EXCEPTION] File Not Found${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}Reason:${NC}  The system cannot locate the specified file."
    echo -e "${BOLD}Target:${NC}  ${INPUT_FILE}"
    echo -e "${BOLD}Action:${NC}  Verify the file path and ensure you have read permissions.\n"
    exit 1
fi

# Calculate file metrics
TOTAL_ROWS=$(wc -l < "$INPUT_FILE" | tr -d ' ')
DATA_ROWS=$((TOTAL_ROWS - 1))

if [[ $TOTAL_ROWS -le 1 ]]; then
    echo -e "\n${RED}[FATAL EXCEPTION] Invalid Data Structure${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}Reason:${NC}  File appears to be empty or contains only headers."
    echo -e "${BOLD}Action:${NC}  Provide a TSV file with at least one row of data.\n"
    exit 1
fi

# Verify Target Column
if ! head -n 1 "$INPUT_FILE" | grep -iq "Asset Names"; then
    echo -e "\n${RED}[FATAL EXCEPTION] Schema Validation Failed${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}Reason:${NC}  Target column 'Asset Names' not found in headers."
    echo -e "${BOLD}Action:${NC}  Ensure the first row contains 'Asset Names' (case-sensitive).\n"
    exit 1
fi

# Show Summary
echo -e "\n${BOLD}File Analysis Summary${NC}"
echo -e "${DIM}› Source File : ${INPUT_FILE}${NC}"
echo -e "${DIM}› Total Rows  : ${TOTAL_ROWS}${NC}"
echo -e "${DIM}› Data Records: ${DATA_ROWS}${NC}"
echo -e "${DIM}› Target Found: Yes ('Asset Names')${NC}\n"

# ==========================================
# Interactive Configuration
# ==========================================
# 1. Ask for Format
while true; do
    echo -ne "${C_GREEN}>${NC} Select output format [csv/json/tsv] ${DIM}(default: csv)${NC}: "
    read -r USER_FORMAT
    FORMAT=${USER_FORMAT:-csv}
    FORMAT=$(echo "$FORMAT" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$FORMAT" =~ ^(csv|tsv|json)$ ]]; then 
        break 
    else
        echo -e "${RED}✕ Invalid format. Please enter csv, tsv, or json.${NC}"
    fi
done

# 2. Ask for Output Filename
BASENAME=$(basename "$INPUT_FILE")
FILENAME="${BASENAME%.*}"
TIMESTAMP=$(date +"%Y-%m-%dT%H_%M_%S")
DEFAULT_OUT="${FILENAME}_normalized_${TIMESTAMP}.${FORMAT}"

echo -ne "${C_GREEN}>${NC} Enter output filename ${DIM}(default: $DEFAULT_OUT)${NC}: "
read -r USER_OUT
OUTPUT_FILE=${USER_OUT:-$DEFAULT_OUT}
echo ""

# ==========================================
# Core Processing Engine (AWK Streamer)
# ==========================================
process_data() {
    awk -F'\t' -v format="$FORMAT" -v total_rows="$TOTAL_ROWS" '
    BEGIN {
        OFS = (format == "tsv" ? "\t" : ",");
    }

    function clean_json(s) {
        gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s);
        gsub(/\t/, "\\t", s); gsub(/\n/, "\\n", s); gsub(/\r/, "\\r", s);
        return s;
    }

    function escape_csv(s) {
        if (s ~ /[",\n\r]/) {
            gsub(/"/, "\"\"", s); return "\"" s "\"";
        }
        return s;
    }

    # First row: Identify Headers
    NR==1 {
        target_col = 0;
        for(i=1; i<=NF; i++) {
            sub(/\r$/, "", $i);
            header[i] = $i;
            if ($i == "Asset Names") target_col = i;
        }

        if (format == "json") { print "["; } 
        else {
            row = "";
            for(i=1; i<=NF; i++) {
                val = (format=="csv") ? escape_csv($i) : $i;
                row = row (i==1 ? "" : OFS) val;
            }
            # Set Column Order Here: Repository -> Image Name -> Image Version
            print row OFS (format=="csv" ? escape_csv("Repository") : "Repository") OFS (format=="csv" ? escape_csv("Image Name") : "Image Name") OFS (format=="csv" ? escape_csv("Image Version") : "Image Version");
        }
    }

    # Data rows
    NR>1 {
        asset = $target_col;
        repo = ""; img_name = ""; img_version = "";

        sub(/^\[?[ \t]*\x27?"?/, "", asset);
        sub(/\x27?"?[ \t]*\]?$/, "", asset);
        split(asset, arr, /\x27?"?[ \t]*,[ \t]*\x27?"?/);
        first_asset = arr[1];

        if (first_asset != "") {
            last_slash = 0;
            for(j=length(first_asset); j>=1; j--) {
                if (substr(first_asset, j, 1) == "/") { last_slash = j; break; }
            }

            if (last_slash > 0) {
                first_slash = index(first_asset, "/");
                repo = substr(first_asset, first_slash, last_slash - first_slash + 1);
                
                # --- STRIP LEADING AND TRAILING SLASHES FROM REPOSITORY ---
                sub(/^\//, "", repo);
                sub(/\/$/, "", repo);
                
                end_part = substr(first_asset, last_slash + 1);
                tag_idx = match(end_part, /[:@]/);

                if (tag_idx > 0) {
                    img_name = substr(end_part, 1, tag_idx - 1);
                    img_version = substr(end_part, tag_idx + 1);
                } else {
                    img_name = end_part; img_version = "latest";
                }
            } else {
                tag_idx = match(first_asset, /[:@]/);
                if (tag_idx > 0) {
                    img_name = substr(first_asset, 1, tag_idx - 1);
                    img_version = substr(first_asset, tag_idx + 1);
                } else {
                    img_name = first_asset; img_version = "latest";
                }
            }
        }

        if (format == "json") {
            if (NR > 2) printf ",\n";
            printf "  {\n";
            for(i=1; i<=NF; i++) {
                printf "    \"%s\": \"%s\",\n", clean_json(header[i]), clean_json($i);
            }
            # Output JSON Order: Repository -> Image Name -> Image Version
            printf "    \"Repository\": \"%s\",\n", clean_json(repo);
            printf "    \"Image Name\": \"%s\",\n", clean_json(img_name);
            printf "    \"Image Version\": \"%s\"\n  }", clean_json(img_version);
        } else {
            row = "";
            for(i=1; i<=NF; i++) {
                val = (format=="csv") ? escape_csv($i) : $i;
                row = row (i==1 ? "" : OFS) val;
            }
            # Append Row Data Order: Repository -> Image Name -> Image Version
            print row OFS (format=="csv" ? escape_csv(repo) : repo) OFS (format=="csv" ? escape_csv(img_name) : img_name) OFS (format=="csv" ? escape_csv(img_version) : img_version);
        }

        # Send Progress to stderr for Bash to read
        if (NR % 50 == 0 || NR == total_rows) {
            print NR > "/dev/stderr"
            fflush("/dev/stderr")
        }
    }

    END {
        if (format == "json" && target_col > 0) print "\n]";
    }
    ' "$INPUT_FILE"
}

# ==========================================
# Execution Control Flow
# ==========================================
log_info "Initializing extraction to ${BOLD}$OUTPUT_FILE${NC}..."

# Synchronous execution pipeline:
# 1. Run engine, routing valid parsed data stdout directly to the file
# 2. Redirect the engine's stderr (progress tracking) to standard pipeline
# 3. Synchronously read that pipeline to update the UI
{
    process_data > "$OUTPUT_FILE"
} 2>&1 | while read -r line; do
    if [[ "$line" =~ ^[0-9]+$ ]]; then
        draw_progress "$line" "$TOTAL_ROWS"
    elif [[ -n "$line" ]]; then
        # Capture and render real AWK errors gracefully
        printf "\n${RED}✕ ERROR: %s${NC}\n" "$line" >&2
    fi
done

# Clean up console output and declare operation success
printf "\n\n"
log_success "Operation complete. Normalization successfully mapped."
log_success "Artifact saved to: ${BOLD}$OUTPUT_FILE${NC}\n"