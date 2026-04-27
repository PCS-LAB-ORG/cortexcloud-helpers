# Cortex XDR / XSIAM Linux Standalone Agent Deployment Script

## 📌 Overview
This repository contains an enterprise-grade Bash script designed to fully automate the deployment of the Cortex XDR / XSIAM Linux agent. 

Instead of manually generating installation packages in the Cortex console, downloading them, and distributing them to endpoints, this script leverages the **Cortex REST API** to automatically:
1. Detect the host OS architecture (`x86_64` or `aarch64`) and package manager (`deb`, `rpm`, or `sh`).
2. Identify the absolute latest agent version available in your Cortex tenant.
3. Generate a fresh, standalone distribution package on-the-fly.
4. Securely download the installation package (handling JWT API authorization).
5. Extract the payload and automatically apply the necessary `cortex.conf` tenant routing configuration.
6. Execute the native package installer seamlessly.

## ✨ Enterprise Features
* **Zero-Touch Configuration:** Automatically extracts and places `cortex.conf` into `/etc/panw/` before installation, ensuring the agent registers to your tenant immediately.
* **Dynamic Environment Detection:** Adapts automatically to Ubuntu/Debian (`dpkg`), RHEL/CentOS/Amazon Linux (`rpm`), or generic Linux distributions (`sh`).
* **Robust Error Handling & Retries:** Implements exponential backoff for all API calls to survive transient network failures.
* **Integrity Validation:** Validates the GZIP payload prior to extraction to prevent corrupted installations or silently failing HTTP errors.
* **Standardized Logging:** Outputs ISO 8601 timestamped logs and includes a dedicated verbose `DEBUG` mode for CI/CD pipeline troubleshooting.
* **Security:** Enforces execution as `root` (required for agent installation) and strictly uses environment variables for API credentials to prevent hardcoded secrets.

---

## 📋 Prerequisites
Before running the script, ensure the target Linux host meets the following requirements:
* **Root Privileges:** The script must be run as `root` (via `sudo -E`).
* **Dependencies:** `curl`, `python3`, `tar`, and `gzip` must be installed on the host.
* **Cortex API Key:** You must have an **Advanced API Key** generated from your Cortex XDR/XSIAM tenant with the `"Distributions"` role/permissions.

---

## ⚙️ Configuration (Environment Variables)

The script relies on environment variables for secure execution. You must export the following variables before running the script:

| Variable | Requirement | Description |
| :--- | :--- | :--- |
| \`CORTEX_FQDN\` | **Required** | Your Cortex tenant API FQDN (e.g., \`api-xxxx.xdr.us.paloaltonetworks.com\`). |
| \`CORTEX_API_KEY_ID\` | **Required** | The ID of your Cortex Advanced API Key. |
| \`CORTEX_API_KEY\` | **Required** | The Cortex Advanced API Key string. |
| \`CORTEX_PACKAGE_NAME\` | Optional | Custom name for the distribution package in the Cortex UI. Defaults to \`Linux_Standalone_Auto_Deploy_<timestamp>\`. |
| \`DEBUG\` | Optional | Set to \`"true"\` to enable highly verbose logging, including cURL attempts, raw payload variables, and execution paths. |

---

## 🚀 Usage Instructions

1. **Download the script to your target host:**
   \`\`\`bash
   curl -O https://<your-repo-path>/deploy_cortex_linux.sh
   chmod +x deploy_cortex_linux.sh
   \`\`\`

2. **Export your API credentials:**
   \`\`\`bash
   export CORTEX_FQDN="api-xxxx.xdr.us.paloaltonetworks.com"
   export CORTEX_API_KEY_ID="123"
   export CORTEX_API_KEY="your-secure-api-key-here"
   \`\`\`

3. **Execute the script as root:**
   *Note: You must use the \`-E\` flag with \`sudo\` to preserve your exported environment variables!*
   \`\`\`bash
   sudo -E ./deploy_cortex_linux.sh
   \`\`\`

---

## 🔍 Execution Phases Explained

When executed, the script progresses through 8 automated phases:
1. **Environment Detection:** Runs \`uname -m\` and checks for \`dpkg\`/\`rpm\` to build the exact \`package_type\` string the API expects (e.g., \`aarch64_deb\`).
2. **Fetching Latest Agent Version:** Queries the \`/get_versions\` endpoint, parses the JSON response using Python, and calculates the highest numerical release.
3. **Creating Distribution:** Triggers a standalone package build on the Cortex backend.
4. **Polling Status:** Waits asynchronously, checking the Cortex server every 30 seconds until the package compilation is reported as "completed".
5. **Fetching Download URL:** Retrieves the secure JWT-based download link.
6. **Downloading Archive:** Injects Cortex API headers to securely fetch the \`.tar.gz\` file and performs an integrity check using \`gzip -t\`.
7. **Extracting and Configuring Agent:** Unpacks the archive, locates \`cortex.conf\`, builds the \`/etc/panw\` directory, and copies the config file to ensure proper tenant routing.
8. **Executing Installation:** Runs the native installer command (e.g., \`dpkg -i <file>\` or \`rpm -ivh <file>\`). Finally, cleans up all temporary files.

---

## 🛠️ Troubleshooting

If the script fails, enable debug mode to see exactly where the breakdown occurred:
\`\`\`bash
export DEBUG="true"
sudo -E ./deploy_cortex_linux.sh
\`\`\`

**Common Errors:**
* \`Missing required environment variables\`: You forgot to export the keys, or you ran \`sudo ./deploy_cortex_linux.sh\` without the \`-E\` flag, causing sudo to drop your user environment variables.
* \`Network request failed with cURL exit code 22\`: This usually indicates an HTTP 4xx or 5xx error. Ensure your API Key has the correct permissions for Distribution Management.
* \`Permission denied\` on \`mkdir /etc/panw\`: You did not run the script as root.
