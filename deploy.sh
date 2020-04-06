#!/usr/bin/env bash

set -x

# export gcp values
export GCP_RPOJECT=gridu-gcp
export GCP_REGION=europe-west3
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/creds/terraform-admin.json
gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}

# activate gcp deployment service account in order to perform gcp resources deployment
gcloud auth list

cd terraform

# terraform folder recognition and deployment
terraform init
terraform apply -auto-approve -var "port=22"
terraform apply -auto-approve -var "port=80"
