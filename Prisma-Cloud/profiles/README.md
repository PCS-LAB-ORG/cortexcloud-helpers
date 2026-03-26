# Container Profiles Fetcher

This script retrieves **container runtime profiles** from **Prisma Cloud Compute** and extracts specific fields into a CSV (or JSON) file for reporting and analysis.

---

## 🔗 Official SDK Reference

This script uses the [Palo Alto Networks PCPI SDK](https://github.com/PaloAltoNetworks/pc-python-integration).

> PCPI (Prisma Cloud Python Integration) is the official SDK for interacting with Prisma Cloud APIs.

---

## 🔧 Requirements

* Python 3.7 or higher
* PCPI SDK installed
* Prisma Cloud Compute credentials

---

## 📦 Installation

Install the **PCPI SDK** using `pip`:

### ✅ Mac / Linux

```bash
pip3 install pcpi
python3 -m pip install pcpi
pip install pcpi
```

### ✅ Windows

```bash
py -m pip install pcpi
python -m pip install pcpi
pip install pcpi
pip3 install pcpi
python3 -m pip install pcpi
```

> 💡 **To update an existing installation**, add the `--upgrade` flag:

```bash
pip3 install --upgrade pcpi
```

---

## 🔐 First-Time Configuration

Run the following in a Python interpreter to generate a credentials file and authenticate:

```python
from pcpi import session_loader
session_loader.load_config()
```

This creates a credentials file at:

```
~/.prismacloud/credentials.json
```

You'll be prompted for your Prisma Cloud API URL, access key, and secret key.

---

## 🚀 Running the Script

```bash
python fetch_container_profiles.py
```

This script will:

* Authenticate with the Prisma Cloud Compute API
* Retrieve **all container runtime profiles**
* Extract key fields
* Save the data to:

  * `container_profiles_output.csv` (default)
  * or `container_profiles_output.json` (optional)

---

## 🛠 Output Format (Optional)

To export as JSON instead of CSV, edit this line in the script:

```python
OUTPUT_FORMAT = 'csv'  # Change to 'json'
```

---

## ✅ Extracted Fields

The following fields are included in the output:

| Field                    | Description              |
| ------------------------ | ------------------------ |
| `state`                  | Current profile state    |
| `learnedStartup`         | Learned startup behavior |
| `_id`                    | Unique identifier        |
| `hash`                   | Image hash               |
| `image`                  | Container image          |
| `os`                     | Operating system         |
| `archived`               | Archived flag            |
| `entrypoint`             | Entrypoint process       |
| `infra`                  | Infra container flag     |
| `processes.static.path`  | Static process path      |
| `processes.static.ppath` | Parent path              |
| `processes.static.md5`   | Process MD5              |
| `imageID`                | Image digest ID          |
| `namespace`              | Kubernetes namespace     |
| `cluster`                | Cluster name             |
| `accountIDs`             | Cloud account IDs        |

---

## 📝 Logging & Status Output

* The script logs progress and errors using Python’s `logging` module.
* You'll see messages in your terminal as the script runs.

---

## 📂 Output Files

Results are saved in the current directory:

* `container_profiles_output.csv`
* or `container_profiles_output.json` (if configured)

---

## ❓ Troubleshooting

* **Credential issues**: Re-run `session_loader.load_config()` to reset credentials.
* **API errors**: Ensure your user role has access to `/api/v1/profiles/container`.
* **Slow API**: You can adjust the pagination `limit` or add retry logic for robustness.

---

## 🧩 Additional Resources

* [PCPI GitHub Repo](https://github.com/PaloAltoNetworks/pc-python-integration)
* [Prisma Cloud API Docs](https://pan.dev/prisma-cloud/api/cwpp/get-profiles-container/)
