#!/bin/bash

MY_SERVICE_BACKEND=$1
MY_SERVICE_PORT=$2
MY_SERVICE_PATH=$3
HOST_DOMAIN=$4

INGRESS_CONTROLLER_NAME=$5
KUBECTL_CONTEXT=$6


#######################################################################
###########            Example Values                      ############
#######################################################################
### MY_SERVICE_BACKEND=kubernetes service name                      ###
### MY_SERVICE_PORT=8080                                            ###
### MY_SERVICE_PATH=/accounts                                       ###
### HOST_DOMAIN=www.microsoft.com                                   ###
###                                                                 ###
### INGRESS_CONTROLLER_NAME=dev-ingress-xfnw8a0                     ###
### KUBECTL_CONTEXT=kube-dev-env-1                                  ###
#######################################################################


#Additional diagnostic information for troubleshooting purposes.
ME=`basename "$0"`
echo "Starting script: $ME"
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`
echo "Script path is $MY_PATH"
echo "Current working directory is: $PWD"

KUBECTL_VER=`(kubectl version --client -o json | jq .clientVersion.gitVersion -r)`
KUBE_SERVER=`(kubectl version -o json --context $CONTEXT | jq .serverVersion.gitVersion -r)`
JQ_VERSION=`(jq --version)`

echo "Invoked the script with params:"
cat << EOF | column -t -s:
Service Name:$MY_SERVICE_BACKEND
Service Port:$MY_SERVICE_PORT
Service URL:$MY_SERVICE_PATH
Domain Name:$HOST_DOMAIN
Ingress Controller Name:$INGRESS_CONTROLLER_NAME
Kube Context:$KUBECTL_CONTEXT
EOF

echo "Invoked the script with params:"
cat << EOF | column -t -s:
Component:Version
KubeCtl Version:$KUBECTL_VER
Kubernetes Version:$KUBE_SERVER
JQ Version:$JQ_VERSION
EOF


# get ingress controllers current configuration in JSON format.
kubectl get ingress $INGRESS_CONTROLLER_NAME -o json --context $KUBECTL_CONTEXT > ingress-conf-pre.json

# If it exists delete existing JSON Element for the URL Path (route).
jq "del( .spec.rules[] | select ( .host ==\"$HOST_DOMAIN\") | .http.paths[] | select (.path == \"$MY_SERVICE_PATH\"))" ingress-conf-pre.json > ingress-conf-cleaned.json

# Add new JSON Element for the URL path (Route).
jq "( .spec.rules[] | select (  .host == \"$HOST_DOMAIN\")) .http.paths += [{"backend": {"serviceName": \"$MY_SERVICE_BACKEND\","servicePort": $MY_SERVICE_PORT },"path": \"$MY_SERVICE_PATH\"}]" ingress-conf-cleaned.json > ingress-conf-ammended.json

# Output the Kube Diff on the resource
echo "Comparing current ingress controller state against desired state."
kubectl diff -f ingress-conf-ammended.json --context  $KUBECTL_CONTEXT

if [ $? -eq 0 ]; then
  echo "INFO: No changes to the ingress controller were found."
elif [ $? -eq 1 ]; then
  echo "INFO: Updating ingress controller with new rules."
  #apply ingress config
  kubectl apply -f ingress-conf-ammended.json --context $KUBECTL_CONTEXT
else
  echo "ERROR: Failed to perform the Kube Diff on the Ingress Controller."
fi

#remove temporary files
rm {ingress-conf-pre.json,ingress-conf-ammended.json,ingress-conf-cleaned.json}

echo "Exited script: $ME"
