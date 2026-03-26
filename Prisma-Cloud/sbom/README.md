# Prisma Cloud Dependency Analysis Workflow

This script automates a comprehensive 3-step workflow to analyze software dependencies within your Prisma Cloud environment. It fetches all known dependencies, matches them against a predefined set of rules, and enriches the matched packages with their source code locations.

## ✨ Features

  * **⚙️ Fully Automated:** Orchestrates a complete 3-step analysis workflow with a single command.
  * **🎯 Rule-Based Matching:** Identifies specific dependencies based on package name and version from an input file.
  * **📍 Source Code Enrichment:** Pinpoints the exact repository and file path where each matched dependency is located.
  * **🛡️ Robust & Resilient:** Includes timeouts for API calls, polite rate-limiting, and intelligent error handling to manage network issues or unexpected API responses.
  * **🔐 Secure Credential Management:** Utilizes the official `pcpi` library to securely handle Prisma Cloud API keys without hardcoding them in the script.
  * **📊 Clean & Professional Logging:** Provides clear, easy-to-read console output that shows the script's progress at every stage while suppressing noisy library logs.

-----

## 🔧 Prerequisites

Before you begin, ensure you have the following:

1.  **Python 3.6+** installed on your system.
2.  **Prisma Cloud API Access:** You must have a Prisma Cloud account with an **Access Key** and **Secret Key**.
3.  **Required Python Package:** The `pcpi` library.

-----

## 🚀 Setup & Installation

Follow these steps to set up your environment.

### 1\. Install Python Dependencies

The script relies on the Prisma Cloud Python Integration (`pcpi`) library. Install it using pip:

```bash
pip install pcpi
```

### 2\. Configure Prisma Cloud Credentials

The script securely loads credentials using `pcpi`. You must create a credentials file.

  * **Create the directory (if it doesn't exist):**

    ```bash
    mkdir -p ~/.prismacloud/
    ```

  * **Create and edit the credentials file:**

    ```bash
    nano ~/.prismacloud/credentials.json
    ```

  * **Add your credentials in the following JSON format.** Use the API URL for your specific Prisma Cloud tenant (e.g., `https://api.prismacloud.io`, `https://api2.prismacloud.io`, etc.).

    ```json
    [
      {
        "alias": "my-prisma-tenant",
        "url": "https://api2.prismacloud.io",
        "identity": "YOUR_ACCESS_KEY_ID",
        "secret": "YOUR_SECRET_KEY"
      }
    ]
    ```

### 3\. Prepare the Input Rules File

The script requires an input file named `output.json` to be in the same directory. This file contains the package rules you want to match. Ensure it follows this structure:

```json
{
  "rules": [
    {
      "package": "requests",
      "minVersionInclusive": "2.28.0",
      "maxVersionInclusive": "2.28.0"
    },
    {
      "package": "django",
      "minVersionInclusive": "4.1.2",
      "maxVersionInclusive": "4.1.2"
    }
  ]
}
```

-----

## ▶️ How to Execute

Once the setup is complete, run the script from your terminal:

```bash
python3 run_dependency_analysis.py
```

The script will display its progress through the three main stages, providing clear status updates and success messages.

-----

## 📝 Expected Output

Upon successful execution, the script will generate three JSON files in the same directory:

1.  **`cspm_dependencies.json`**: A complete list of all software dependencies found in your Prisma Cloud tenant.
2.  **`matched_ids.json`**: An intermediate file containing a list of the unique IDs for packages that matched the rules in `output.json`.
3.  **`source_locations.json`**: The final report. This file contains detailed information about where each matched dependency is located.

#### Example `source_locations.json` structure:

```json
[
    {
        "matchedId": "ConcretePackage_python_requests_2.28.0_...",
        "sourceLocations": [
            {
                "name": "my-org/my-app-repo",
                "id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
                "filePath": "/requirements.txt",
                "packageManager": "Pip",
                "locationUrl": "https://github.com/my-org/my-app-repo/blob/main/requirements.txt#L10"
            }
        ]
    }
]
```

-----

## 🐛 Troubleshooting Common Errors

If you encounter issues, refer to the common problems and solutions below.

### Authentication Failure

If you see an error like this, it means your API credentials are incorrect.

  * **Error Log:**

    ```
    2025-10-01 10:23:29 -  [🔐] Authenticating and creating API session...
    ERROR:pcpi:FAILED
    WARNING:pcpi:Invalid Login Credentials. JWT not generated.
    WARNING:pcpi:Update your custom credentials file or the default file in `~/.prismacloud`. Exiting...
    ```

  * **💡 Solution:**

    1.  **Verify your credentials file** at `~/.prismacloud/credentials.json`.
    2.  Check for typos in your **`identity`** (Access Key) and **`secret`** (Secret Key).
    3.  Ensure the **`url`** is correct for your Prisma Cloud tenant. A common mistake is using `https://api.prismacloud.io` when your tenant is on `https://api2.prismacloud.io` or another regional endpoint.

### Input File Not Found

  * **Error Log:**

    ```
    [✖︎] FAILED: Prerequisite file not found: 'output.json'.
    ```

  * **💡 Solution:**

      * Make sure the rules file, named exactly `output.json`, exists in the **same directory** where you are running the script.

### API Timeout or HTML Response

  * **Error Log:**

    ```
    [✖︎] API call to '...' timed out after 30 seconds.
    ```

    *or*

    ```
    [✖︎] API call to '...' failed: Expected JSON response but received 'text/html'
    ```

  * **💡 Solution:**

      * **Timeout:** This usually indicates a temporary network issue or a slow response from the Prisma Cloud API. Try running the script again after a few minutes.
      * **HTML Response:** This often points to a network or authentication problem.
          * Check if you need to be connected to a **VPN** to reach your company's Prisma Cloud instance.
          * Verify that your API session has not expired.
          * Ensure no network proxy is interfering with the API calls.