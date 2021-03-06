#!/bin/bash

# 
#   Sets up the environment and secrets necessary for the devops-sandbox-cluster Kubernetes instance in Azure.
#    
#   Authors: James Eby
#

export ORIG_DIR=$(pwd)

export CLUSTER_FILES_PATH=$ORIG_DIR
export COMMON_FILES_PATH="$(dirname "$ORIG_DIR")"/common
export COMMON_BASH_FILES_PATH=$COMMON_FILES_PATH/bash-files

# Make sure we are where we need to be to setup the kubeconfig properly
cd $CLUSTER_FILES_PATH

# Connect to proper cluster in this command window.
. $CLUSTER_FILES_PATH/../../../cloud-ops/azure/demo-prodbeta-cluster/init-kube-connection.sh

# # Set necessary secrets as environment variables.
# #. ../../azure/devops-sandbox-cluster/.secrets/set-sql-server-environment-variables.sh
. $COMMON_FILES_PATH/.secrets/set-external-resources-environment-variables.sh

# NAMESPACES
# Create namespace build for jenkins and harbor.
export NAMESPACE_NAME=build
. $COMMON_BASH_FILES_PATH/create-namespace.sh

# Create the production namespace for production versions of apps built in cluster.
export NAMESPACE_NAME=production
. $COMMON_BASH_FILES_PATH/create-namespace.sh

# Create the beta namespace namespace for beta versions of apps built in cluster.
export NAMESPACE_NAME=beta
. $COMMON_BASH_FILES_PATH/create-namespace.sh

# SERVICE ACCOUNTS
# Create service account and RBAC for jenkins build server account.
kubectl create sa jenkins-builder -n build
kubectl create clusterrolebinding jenkins-cr-binding --clusterrole cluster-admin --serviceaccount=build:jenkins-builder

# With Azure RBAC enabled we need to give the kubernetes-dashboard user proper RBAC administer cluster resources
kubectl create clusterrolebinding kubernetes-dashboard-cr-binding --clusterrole cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

# Create service account and RBAC for tiller.
kubectl create sa tiller -n kube-system
kubectl create clusterrolebinding tiller-cr-binding --clusterrole cluster-admin --serviceaccount=kube-system:tiller

# SECRETS

#NOTE: NEVER EVER PUT A $ IN A PASSWORD FOR THESE USERS, it won't work -p parameter which also affects Jenkins.
if [ "$REGISTRY_URL" == 'hub.docker.com' ]
then
    # Create the private docker registry connection secret.
    kubectl create secret docker-registry registry-regcred --docker-server=https://index.docker.io/v1/ --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n build --docker-server=https://index.docker.io/v1/ --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n production --docker-server=https://index.docker.io/v1/ --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n beta --docker-server=https://index.docker.io/v1/ --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
else
    # Create the private docker registry connection secret.
    kubectl create secret docker-registry registry-regcred --docker-server=https://${REGISTRY_URL} --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n build --docker-server=https://${REGISTRY_URL} --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n production --docker-server=https://${REGISTRY_URL} --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create secret docker-registry registry-regcred -n beta --docker-server=https://${REGISTRY_URL} --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_USER_PASSWORD --docker-email=$REGISTRY_EMAIL
fi

# Give jenkins service account right to pull images from private repository.
kubectl patch serviceaccount -n build jenkins-builder -p '{"imagePullSecrets": [{"name": "registry-regcred"}]}'

# Create the jenkins credentials.xml file secret.
kubectl create secret generic jenkins-credentials -n build --from-file $COMMON_FILES_PATH/.secrets/jenkins/credentials.xml

# Create the master.key and hudson.util.Secret files secret.
kubectl create secret generic jenkins-secrets -n build \
    --from-file $COMMON_FILES_PATH/.secrets/jenkins/hudson.util.Secret \
    --from-file $COMMON_FILES_PATH/.secrets/jenkins/master.key

# Setup external resource secrets for use by jenkins and potentially others.
kubectl create secret generic jenkins-env-secrets -n build \
    --from-literal=addenv_REGISTRY_URL=$REGISTRY_URL \
    --from-literal=addenv_REGISTRY_USER_ID=$REGISTRY_USER_ID \
    --from-literal=addenv_PRIVATE_GIT_REPO_URL=$PRIVATE_GIT_REPO_URL \
    --from-literal=addenv_PRIVATE_GIT_REPO_USER_ID=$PRIVATE_GIT_REPO_USER_ID \
    --from-literal=addenv_PUBLIC_GIT_REPO_URL=$PUBLIC_GIT_REPO_URL \
    --from-literal=addenv_PUBLIC_GIT_REPO_USER_ID=$PUBLIC_GIT_REPO_USER_ID \
    --from-literal=addenv_NUGET_API_KEY=$NUGET_API_KEY \
    --from-literal=addenv_AGENT_IMAGE=jenkins-agent:latest

# Setup standard mail secrets for use by multiple apps.
kubectl create secret generic smtp-env-secrets -n production \
    --from-literal=MAIL__SMTPSERVER=$MAIL__SMTPSERVER \
    --from-literal=MAIL__SMTPPORT=$MAIL__SMTPPORT \
    --from-literal=MAIL__SMTPUSERNAME=$MAIL__SMTPUSERNAME \
    --from-literal=MAIL__SMTPPASSWORD=$MAIL__SMTPPASSWORD \
    --from-literal=MAIL__SMTPENABLESSL=$MAIL__SMTPENABLESSL

# Setup standard db secrets for use by multiple apps.
# kubectl create secret generic db-env-secrets -n production \
#     --from-literal=DB__SERVERNAME=$AZURE_SQL_SERVER \
#     --from-literal=DB__USERNAME=$AZURE_SQL_SERVER_ADMIN_USER \
#     --from-literal=DB__USERPASSWORD=$AZURE_SQL_SERVER_ADMIN_PASSWORD

# Setup standard db secrets for use by multiple apps.
kubectl create secret generic sts-env-secrets -n production \
    --from-literal=AUTH0_DOMAIN=$AUTH0_DOMAIN \
    --from-literal=AUTH0_CLIENTID=$AUTH0_CLIENTID_PROD \
    --from-literal=AUTH0_CLIENTSECRET=$AUTH0_CLIENTSECRET_PROD

kubectl create secret generic sts-env-secrets -n beta \
    --from-literal=AUTH0_DOMAIN=$AUTH0_DOMAIN \
    --from-literal=AUTH0_CLIENTID=$AUTH0_CLIENTID_PROD \
    --from-literal=AUTH0_CLIENTSECRET=$AUTH0_CLIENTSECRET_PROD
    
# Create the secret that apps can use to tell what environments they are.
kubectl create secret generic standard-env-secrets -n build \
    --from-literal=ENVIRONMENT_NAME=build

kubectl create secret generic standard-env-secrets -n production \
    --from-literal=ENVIRONMENT_NAME=production

kubectl create secret generic standard-env-secrets -n beta \
    --from-literal=ENVIRONMENT_NAME=beta