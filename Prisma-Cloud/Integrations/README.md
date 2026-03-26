
---

# Integrate Multiple Repositories

Welcome to the **Integrate Multiple Repositories tool**. This tool automates the process of onboarding multiple repositories using the Prisma API. It's designed to be simple, efficient, and user-friendly.

---

## 📖 Table of Contents

- [🚀 Introduction](#-introduction)
- [🔧 Prerequisites](#-prerequisites)
- [📂 Usage](#-usage)
  - [🌍 Environment Variables](#environment-variables)
  - [📝 Input File](#input-file)
- [⚙️ Commands](#-commands)
  - [`update_integration`](#update_integration)
- [💡 Troubleshooting](#-troubleshooting)
- [📊 Example Use Case](#-example-use-case)

---

## 🚀 Introduction

This script automates the updating of **Yor tag rules** for a set of repositories. It interacts with the Prisma API to perform authentication and execute API requests, ensuring that your repositories stay up-to-date.

---

## 🔧 Prerequisites

Before you begin, ensure you have the following:

- **Environment Variables**: The following environment variables must be set up in your environment.
  - `PRISMA_API_URL`: URL of the Prisma API.
  - `PRISMA_ACCESS_KEY_ID`: Prisma API access key ID.
  - `PRISMA_SECRET_KEY`: Prisma API secret key.
  - `PRISMA_INT_ID`: VCS Integration Id.

- **Input File**: A text file containing the repository owner and name combinations, one per line. See the [Input File](#input-file) section for formatting details.

---

## 📂 Usage

### 🌍 Environment Variables

Make sure the following variables are available in your environment before running the script:

- **`PRISMA_API_URL`**: URL of your Prisma API endpoint.
- **`PRISMA_ACCESS_KEY_ID`**: Your Prisma access key ID for authentication.
- **`PRISMA_SECRET_KEY`**: Your Prisma secret key.
- **`PRISMA_INT_ID`**: Integration ID.


### 📝 Input File

The **input file** should list the repositories in the format `owner/repository` (one per line). Here's an example:

```plaintext
user1/repo1
user2/repo2
user3/repo3
```

**Tip:** Make sure there are no empty lines or extra spaces.

---

## ⚙️ Commands

### `update_integration()`

This function updates the **integration for repositories** for the specified repositories using the Prisma API.

---

## 💡 Troubleshooting

Encountering issues? Follow these steps to resolve them:

- **Environment Variables**: Ensure all required environment variables are correctly set.
- **Input File Format**: Verify that the input file follows the `owner/repository` format without any mistakes.
- **API Health**: Double-check that the Prisma API is running and accessible.

---

## 📊 Example Use Case

To update the Yor tag rule for your repositories, simply run the script with the following command:

```bash
python IntMultiRepos.py
```

The script will process the repositories listed in your input file and update the Yor tag rules accordingly.

---

This version improves the **readability** and **user experience** by adding:
- Clear, **concise headings** for each section.
- **Icons** to visually engage users and highlight important information.
- **Helpful tips** to avoid common mistakes.

Let me know if you need further adjustments!
