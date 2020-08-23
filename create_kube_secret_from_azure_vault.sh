which jq >/dev/null
if [ $? -gt 0 ]; then echo "jq version 1.5 or higher is required to be installed and avilable on the PATH."; exit 0; fi
JQ_VERSION=`(jq --version)`

which base64  >/dev/null
if [ $? -gt 0 ]; then echo "base64 is required to be installed and avilable on the PATH."; exit 0; fi

function show_help() {
local __usage="
NAME
  create_kube_secret_from_azure_vault

SYNOPSIS
  create_kube_secret_from_azure_vault [ -i filename ] [ -o directory]

DESCRIPTION
This script automates the creation of Kubernetes Secret Config files, using an input configuration file, and then gathering the required secrets from Az KeyVault
-i    --input-file            The location of the json file, for which the generate the Kubernetes Secret config files.
-o    --output-directory      The diectory to output the Kubernetes Secret config files.
-t    --show-sample-template  Show's a sample of the temple to use as an input for this command.

-h    --help                  This help message.

NOTE
  The generated files will be named after the Kubernetes Secret specified in the input file. 
  All generated files will be generated in the JSON formated and have the file extention .json.


EXAMPLE
  create_kube_secret_from_azure_vault -i myApplicationName.json -o ~/secrets

EXIT STATUS
Incomplete, do not use.
"
echo "$__usage"
}

function show_sample_template() {
local __usage='
{
    "kubernetesSecrets": 
    [
        { 
            "name" : "KubernetesSecretName",
            "data" : 
            [ 
                {
                    "vaultName": "AzureVaultName",
                    "secrets" :
                    [
                        { 
                            "key" : "AzureSecretName1" 
                        },
                        {
                            "key" : "AzureSecretName2"
                        }
                    ]
                }
            ]
        }
    ]
}
'   
echo "$__usage"
}


while [[ $# -gt 0 ]]
do
    key="${1}"
    case ${key} in
    -i|--input-file)
        if [[ "$1" != *=* ]]; then shift; fi
        FILENAME="${1}"
        ;;
    -o|--output-directory)
        if [[ "$1" != *=* ]]; then shift; fi
        OUT_DIR="${1}"
        ;;
    -t|--show-sample-template)
        show_sample_template
        exit 0
        shift # past argument
        ;;
    -h|--help)
        show_help
        exit 0
        shift # past argument
        ;;
    *)    # unknown option
        show_help
        exit 1
        shift # past argument
        ;;
    esac
    shift
done

if [ -z $FILENAME ]; then
  echo -e "Please provide an Input file. Use the -t switch to view the required file format."
  exit 5
fi

if [ -z $OUT_DIR ]; then
  echo -e "No output directory specified, will fallback to $PWD."
  OUT_DIR=$PWD
fi


echo "Invoked the script with the follow configuration:"
cat << EOF | column -t -s:
Setting:Values
Input file:$FILENAME
Output Directory:$OUT_DIR
jq Version:$JQ_VERSION
EOF

# Generate empty K8 secret template
KUBE_SECRET_TEMPLATE='{"apiVersion": "v1","kind": "Secret","metadata": {"name": "SECRET_NAME"},"data": []}'

# Get the Kube secret name to set.
SECRET_NAMES=`(cat $FILENAME | jq -r ".kubernetesSecrets[].name")` # Get K8 secret name

# For each secret name:
for SECRET_NAME in $SECRET_NAMES
do
    # create a new secret template and set the name.
    THIS_SECRET_TEMPLATE=`( echo $KUBE_SECRET_TEMPLATE | jq ".metadata.name = \"$SECRET_NAME\"" )`

    # get the vault names used by this secret set.
     VAULT_NAMES=`(cat $FILENAME | jq -r ".kubernetesSecrets[] | select ( .name == \"$SECRET_NAME\" ) | .data[].vaultName" )`

    for VAULT_NAME in $VAULT_NAMES
    do
            # get the vault secret key names.
            VAULT_SECRET_NAMES=`(cat $FILENAME | jq -r ".kubernetesSecrets[] | select ( .name == \"$SECRET_NAME\" ) | .data[] | select ( .vaultName == \"$VAULT_NAME\") | .secrets[].key")`

            for VAULT_SECRET_NAME in $VAULT_SECRET_NAMES
            do
                echo "Getting secret [$VAULT_SECRET_NAME] from vault [$VAULT_NAME]."
                VAULT_SECRET_VALUE=`(az keyvault secret show --vault-name $VAULT_NAME --name $VAULT_SECRET_NAME | jq -r ".value" )`               
                # base64 encode the value.
                ENC_SECRET_VALUE=`( echo -n "$VAULT_SECRET_VALUE" | base64 )`
                # add the vault secret name and value to the JSON file.
                THIS_SECRET_TEMPLATE=`( echo $THIS_SECRET_TEMPLATE | jq ".data += [ { \"$VAULT_SECRET_NAME\" : \"$ENC_SECRET_VALUE\" } ]" )`
            done
    done

    echo $THIS_SECRET_TEMPLATE > $OUT_DIR/$SECRET_NAME.json
done
