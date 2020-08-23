#!/bin/bash

function show_help() {
local __usage='
NAME
  get_environment_info_from_json -- Get the values for an environment from a Json File, using the Simplief-T environment format.

SYNOPSIS
  get_environment_info_from_json -e environment_name -v lookup_key

DESCRIPTION

-e    --environment-name      The name environment.
-k    --lookup-key            The key to lookup within the enviornment. 
-f    --filename              The name of the Json file to use, defaults to env.json.

-h    --help                  This help message.

EXAMPLE
  get_environment_info_from_json -e production -v domainName

  // env.json //
    {
        "environments": [
            {
                "name": "dev",
                "clusterName": "myDevCluster",
                "clusterResourceGroup": "myDevResourceGroup",
                "ingressName": "devIngressName",
                "domainName": "dev.mydomain.com"
            },
            {
                "name": "qa",
                "clusterName": "myQaCluster",
                "clusterResourceGroup": "myQaResourceGroup",
                "ingressName":"qaIngressName",
                "domainName": "qa.mydomain.com"
            }
        ]
    }

EXIT STATUS
Return.

'
echo "$__usage"
}


while [[ $# -gt 0 ]]; do
    case "$1" in
    -e|--environment-name)
        if [[ "$1" != *=* ]]; then shift; fi
        GET_ENV_NAME="${1}"
	;;
    -k|--lookup-key)
	if [[ "$1" != *=* ]]; then shift; fi
        GET_DETAIL_NAME="${1}"
	;;
    -f|--filename)
	if [[ "$1" != *=* ]]; then shift; fi
	ENV_FILENAME="${1}"
	;;
    -h|--help)
        show_help
        exit 0
	;;
    *)    # unknown option
        >&2 echo "ERROR: Invalid argument"
	exit 1
        ;;
    esac
    shift
done

if [ -z $ENV_FILENAME ]; then
  ENV_FILENAME="env.json"
fi

if [ -z $GET_ENV_NAME ]; then
  echo -e "Please provide an environment name."
  exit 1
fi

if [ -z $GET_DETAIL_NAME ]; then
  echo -e "Please provide key name to lookup."
  exit 1
fi

if [ ! -f $ENV_FILENAME ]; then
  echo -e "The file environment file [$ENV_FILENAME] is missing."
  exit 1
fi

ENV_VALUE=`( jq ".environments[] | select ( .name == \"$GET_ENV_NAME\").\"$GET_DETAIL_NAME\"" -r $ENV_FILENAME)`
JQ_STATUS=$?

if [ $JQ_STATUS -eq 0 ]; then
  echo "$ENV_VALUE"
else
  echo -e "ERROR: Failed to retrieve the request value from the Json file."
  exit $JQ_STATUS
fi
