#!/usr/bin/env bash

set -x

# export gcp values
export GCP_RPOJECT=gridu-gcp
export GCP_REGION=europe-west3
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/creds/terraform-admin.json
gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}

gcloud auth list

cd terraform



gsutil mb -p ${GCP_REGION} -s coldline -l ${GCP_RPOJECT} gs://${GCP_REGION}/gridu

terraform init
terraform apply -auto-approve -var "port=22"
terraform apply -auto-approve -var "port=80"