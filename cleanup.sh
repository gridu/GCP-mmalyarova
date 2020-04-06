#!/usr/bin/env bash

set -x

cd terraform

# perform terraform resources cleanup
terraform destroy -auto-approve