# Floci + OpenTofu Sample (S3, DynamoDB, Python Lambda)

A sample project demonstrating how to provision local AWS infrastructure on **[Floci](https://github.com/floci-io/floci)** (`http://localhost:4566`) using **OpenTofu** (`tofu`).

It packages and deploys a Python 3.12 AWS Lambda function that writes records to a local **DynamoDB** table and uploads JSON snapshots to a local **S3** bucket.

---

## Architecture & Resources

```text
+-------------------------------------------------------------------------+
|                     Floci (http://localhost:4566)                       |
|                                                                         |
|   +-------------------------------+     PutItem     +---------------+   |
|   |      aws_lambda_function      | --------------> |  DynamoDB     |   |
|   |   (floci-sample-python-fn)    |                 | (FlociSample  |   |
|   |      runtime: python3.12      |                 |    Items)     |   |
|   +-------------------------------+                 +---------------+   |
|                   |                                                     |
|                   | PutObject (items/<id>.json)                         |
|                   v                                                     |
|   +-------------------------------+                                     |
|   |         aws_s3_bucket         |                                     |
|   |     (floci-sample-bucket)     |                                     |
|   +-------------------------------+                                     |
+-------------------------------------------------------------------------+
```

| Resource Type | Resource Name / Identifier | Description |
| :--- | :--- | :--- |
| `aws_s3_bucket` | `floci-sample-bucket` | Local S3 bucket storing JSON item snapshots (`items/<id>.json`). |
| `aws_dynamodb_table` | `FlociSampleItems` | Pay-per-request DynamoDB table with partition key `id` (`S`). |
| `aws_iam_role` | `floci_lambda_exec_role` | IAM execution role and inline policy granting S3 and DynamoDB permissions. |
| `aws_lambda_function` | `floci-sample-python-fn` | Python 3.12 Lambda (`handler.lambda_handler`) packaged from `./src`. |

---

## Project Structure

```text
floci-tofu-sample/
├── .gitignore           # Ignores OpenTofu state, Lambda build zip, and Floci data
├── docker-compose.yml   # Runs local Floci container on port 4566
├── providers.tf         # OpenTofu & AWS provider config pointing to localhost:4566
├── main.tf              # S3, DynamoDB, IAM, and Lambda resource definitions
├── outputs.tf           # Outputs for bucket, table, and Lambda function names/ARNs
└── src/
    └── handler.py       # Python 3.12 Lambda handler writing to DynamoDB & S3
```

---

## Prerequisites

- **Docker** & **Docker Compose** (for running Floci and local Lambda containers)
- **OpenTofu** `>= 1.6.0` (`tofu`)
- **AWS CLI** (`aws`) for invoking the Lambda function and inspecting S3 / DynamoDB resources

---

## Setup & Run Instructions

### 1. Start Floci Locally

From the `floci-tofu-sample` directory, start the Floci service using Docker Compose:

```bash
cd floci-tofu-sample
docker compose up -d
```

Verify the container is running and listening on port `4566`:

```bash
docker compose ps
```

> **Note:** `docker-compose.yml` mounts `/var/run/docker.sock` into the Floci container so Floci can spin up local Lambda execution containers.

---

### 2. Initialize & Apply OpenTofu Configuration

Initialize the OpenTofu working directory (downloads the `hashicorp/aws` and `hashicorp/archive` providers):

```bash
tofu init
```

Preview the execution plan:

```bash
tofu plan
```

Apply the configuration to create the S3 bucket, DynamoDB table, IAM role, and Python Lambda function inside Floci:

```bash
tofu apply -auto-approve
```

Expected outputs:

```text
Outputs:

dynamodb_table_name  = "FlociSampleItems"
lambda_function_arn  = "arn:aws:lambda:us-east-1:000000000000:function:floci-sample-python-fn"
lambda_function_name = "floci-sample-python-fn"
s3_bucket_name       = "floci-sample-bucket"
```

---

### 3. Test & Verify Resources

Set dummy AWS credentials in your shell (or pass them inline) and point the AWS CLI to `http://localhost:4566`:

```bash
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export ENDPOINT="http://localhost:4566"
```

#### A. Invoke the Lambda Function

```bash
aws --endpoint-url="$ENDPOINT" lambda invoke \
  --function-name floci-sample-python-fn \
  --cli-binary-format raw-in-base64-out \
  --payload '{"id": "item-101", "message": "Testing Floci with OpenTofu!"}' \
  response.json

cat response.json
```

#### B. Verify the Item in DynamoDB

```bash
aws --endpoint-url="$ENDPOINT" dynamodb get-item \
  --table-name FlociSampleItems \
  --key '{"id": {"S": "item-101"}}'
```

Or scan the entire table:

```bash
aws --endpoint-url="$ENDPOINT" dynamodb scan \
  --table-name FlociSampleItems
```

#### C. Verify the JSON Snapshot in S3

List objects in `floci-sample-bucket`:

```bash
aws --endpoint-url="$ENDPOINT" s3 ls s3://floci-sample-bucket/items/
```

Download and inspect the uploaded JSON object:

```bash
aws --endpoint-url="$ENDPOINT" s3 cp s3://floci-sample-bucket/items/item-101.json -
```

---

## Customizing the Floci Endpoint

By default, [`providers.tf`](./providers.tf) connects to `http://localhost:4566`. To use a custom Floci host or port, override the `floci_endpoint` variable:

```bash
tofu apply -var="floci_endpoint=http://localhost:4566"
```

---

## Teardown & Cleanup

Destroy the OpenTofu-managed resources:

```bash
tofu destroy -auto-approve
```

Stop and remove the Floci container (and optionally remove persisted local data):

```bash
docker compose down
rm -rf floci-data build response.json
```

