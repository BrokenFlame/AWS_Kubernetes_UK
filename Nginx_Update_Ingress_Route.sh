#!/bin/bash

function show_help() {
__usage="
NAME
  add_kube_nginx_route -- Adds a route to an existing Nginx ingress controller.

SYNOPSIS
  add_kube_ngnix_route [ -b backend ]  [ -c context]  [ -d domain ] [ -i ingressname]  [ -p portnumber ] [ -u url ] 

DESCRIPTION

-b    --backend               The name of the backend service to associate the route with.
-c    --kube-context          The Kubectl context to use to connect to the Kubernetes API Server. 
-d    --domain                The domain name under which to configure the route, i.e. www.mydomain.com
-i    --ingress-controller    The name of the Nginix ingress controller to configure.
-p    --backend-port          The port number if the backend service, the default is 8080.
-u    --url_path              The url of the route to be configured, the default is /

-h    --help                  This help message.

EXAMPLE
  add_kube_nginx_route -b backend_service -c kubectl_context -d www.mydomain.com -i ingress_name -p backend_service_port -u /accounts/customers

EXIT STATUS
Incomplete, do not use.

"
echo "$__usage"
}


while [[ $# -gt 0 ]]
do
    key="${1}"
    case ${key} in
    -b|--backend)
        MY_SERVICE_BACKEND="${2}"
        shift # past argument
        shift # past value
        ;;
    -p|--backend-port)
         MY_SERVICE_PORT="${2:-8080}"
        shift # past argument
        shift # past value
        ;;
    -d|--domain)
        HOST_DOMAIN="${2}"
        shift # past argument
        shift # past value
        ;;
    -u|--url_path)
        MY_SERVICE_PATH="${2:-/}"
        shift # past argument
        shift # past value
        ;;
    -i|--ingress-controller)
        INGRESS_CONTROLLER_NAME="${2}"
        shift # past argument
        shift # past value
        ;;
    -c|--kube-context)
        KUBECTL_CONTEXT="${2}"
        shift # past argument
        shift # past value
        ;;
    -h|--help)
        show_help
        shift # past argument
        ;;
    *)    # unknown option
        shift # past argument
        ;;
    esac
    shift
done

# Check required parameters are not null.
if [ -z $KUBECTL_CONTEXT ]; then
  echo "Kubectl Context cannot be null, please provide a context."
  exit 1
fi

if [ -z $INGRESS_CONTROLLER_NAME ]; then
  echo "Kubernetes ingress name cannot be null, please provide a ingress name."
  exit 1
fi

if [ -z $HOST_DOMAIN ]; then
  echo "Domain name cannot be null, please provide a domain name for the ingress controller context."
  exit 1
fi

if [ -z $MY_SERVICE_BACKEND ]; then
  echo "Backend service name cannot be null, please provide a service to use for the backend."
  exit 1
fi

#Additional diagnostic information for troubleshooting purposes.
ME=`basename "$0"`
echo "Starting script: $ME"
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`
echo "Script path is $MY_PATH"
echo "Current working directory is: $PWD"

KUBECTL_VER=`(kubectl version --client -o json | jq .clientVersion.gitVersion -r)`
KUBE_SERVER=`(kubectl version -o json --context $KUBECTL_CONTEXT | jq .serverVersion.gitVersion -r)`
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
