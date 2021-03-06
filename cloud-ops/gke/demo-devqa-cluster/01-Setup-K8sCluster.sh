#!/bin/bash
# This bash script creates a kubernetes cluster in whatever GCP project is selected at login.

# Run if you need to init init the SDK and set the current user and the current project. This can be commented out if not needed.
# gcloud init

export CLUSTER_NAME='devqa-cluster'
export CLUSTER_ZONE='us-east1-b'
export NODE_COUNT=3

# Creat the new cluster (Use a version of GKE that uses docker 18.X for multistage build support).
gcloud container clusters create $CLUSTER_NAME --cluster-version=1.13.6-gke.13 --num-nodes $NODE_COUNT  --zone $CLUSTER_ZONE --machine-type=n1-standard-2 --enable-ip-alias --enable-autorepair --enable-autoupgrade

# Get the proper credentials with which to work with kubectl
gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE

cd ../../../cluster-ops/kubernetes/demo-devqa-cluster/