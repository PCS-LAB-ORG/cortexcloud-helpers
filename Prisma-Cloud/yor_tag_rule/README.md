=====================================

Table of Contents
-----------------

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
        + [Environment Variables](#environment-variables)
        + [Input File](#input-file)
* [Commands](#commands)
        + [`update_tag_rule()`](#updatetagrule)
* [Troubleshooting](#troubleshooting)

Introduction
------------

This script updates the Yor tag rule for a given set of repositories. It uses the Prisma API to 
authenticate and make requests.

Prerequisites
-------------

* The `PRISMA_API_URL`, `PRISMA_ACCESS_KEY_ID`, and `PRISMA_SECRET_KEY` environment variables must be 
set.
* An input file containing the repository owner and name combinations, one per line (see [Input 
File](#input-file) for format).

Usage
-----

### Environment Variables

The following environment variables are required:

* `PRISMA_API_URL`: The URL of the Prisma API.
* `PRISMA_ACCESS_KEY_ID`: The access key ID for the Prisma API.
* `PRISMA_SECRET_KEY`: The secret key for the Prisma API.

### Input File

The input file should contain one repository owner and name combination per line, in the format 
`owner/repository`. For example:

```
user1/repo1
user2/repo2
...
```

Commands
--------

### `update_tag_rule()`

This function updates the Yor tag rule for the given repositories. It uses the Prisma API to 
authenticate and make requests.

Troubleshooting
--------------

If you encounter any issues with the script, please refer to the following troubleshooting steps:

* Check that the environment variables are set correctly.
* Verify that the input file is in the correct format.
* Make sure that the Prisma API is functioning correctly.

Example Use Case
-----------------

To update the Yor tag rule for a given set of repositories, run the script with the 
`update_tag_rule()` function. For example:

```bash
python yor_tag_rule.py
```
