#!/usr/bin/env bash
#
#  Purpose: Generate Root and Intermediate CA then register to Hub and DPS
#  Usage:
#    run.sh


if [ -f ./.envrc ]; then source ./.envrc; fi

usage() { echo "Usage: run.sh " 1>&2; exit 1; }


function create_ca_certs()
{
    ##############################
    ## Creating PKI CA Certs    ##
    ##############################
    printf "\n"
    tput setaf 2; echo "Generating Root and Intermediate Certificate Authorities" ; tput sgr0
    tput setaf 3; echo "--------------------------------------------------------" ; tput sgr0

    if [ ! -d pki ]; then mkdir pki; fi
    ./generate.sh ca
}

function archive_in_keyvault()
{
    ##############################
    ## Backup PKI to KeyVault   ##
    ##############################
    printf "\n"
    tput setaf 2; echo "Loading PKI to KeyVault" ; tput sgr0
    tput setaf 3; echo "-----------------------" ; tput sgr0

    # Store the Root CA Key Password in the Vault
    az keyvault secret set \
    --vault-name $VAULT \
    --name "$ORGANIZATION-ROOT-CA-PASSWORD" \
    --value $ROOT_CA_PASSWORD \
    -oyaml

    # Store the Intermediate CA Key Password in the Vault
    az keyvault secret set \
    --vault-name $VAULT \
    --name "$ORGANIZATION-INT-CA-PASSWORD" \
    --value $INT_CA_PASSWORD \
    -oyaml

    # Store the Root CA Private Key in the Vault
    az keyvault key import \
    --vault-name $VAULT \
    --name "${ORGANIZATION}-root-ca-key" \
    --pem-password $ROOT_CA_PASSWORD \
    --pem-file "./pki/private/${ORGANIZATION}.root.ca.key.pem" \
    -oyaml

    # Store the Intermediate CA Private Key in the Vault
    az keyvault key import \
    --vault-name $VAULT \
    --name "${ORGANIZATION}-intermediate-key" \
    --pem-password $INT_CA_PASSWORD \
    --pem-file "./pki/private/${ORGANIZATION}.intermediate.key.pem" \
    -oyaml

    # Store the Root CA Certificate in the Vault
    az keyvault certificate import \
    --vault-name $VAULT \
    --name "${ORGANIZATION}-root-ca" \
    --password $ROOT_CA_PASSWORD \
    --file "./pki/certs_pfx/${ORGANIZATION}.root.ca.cert.pfx" \
    -oyaml

    # Store the Intermediate CA Certificate in the Vault
    az keyvault certificate import \
    --vault-name $VAULT \
    --name "${ORGANIZATION}-intermediate-ca" \
    --password $INT_CA_PASSWORD \
    --file "./pki/certs_pfx/${ORGANIZATION}.intermediate.cert.pfx" \
    -oyaml
}

function validate_to_hub()
{
    #######################################
    ## Upload Intermediate CA to IoT Hub ##
    #######################################
    printf "\n"
    tput setaf 2; echo "Uploding Intermediate CA Certificate to IoT Hub" ; tput sgr0
    tput setaf 3; echo "-----------------------------------------------" ; tput sgr0

    # Upload the Certificates to IoT Hub
    az iot hub certificate create \
    --name "${ORGANIZATION}-intermediate" \
    --hub-name $HUB \
    --path pki/certs/${ORGANIZATION}.intermediate.cert.pem \
    -oyaml

    # Retrieve the Certificate ETAG
    ETAG=$(az iot hub certificate show \
            --name "${ORGANIZATION}-intermediate" \
            --hub-name $HUB \
            --query etag -otsv)

    # Generate a Verification Code for the Certificate
    CODE=$(az iot hub certificate generate-verification-code \
                    --name "${ORGANIZATION}-intermediate" \
                    --hub-name $HUB \
                    --etag $ETAG \
                    --query properties.verificationCode -otsv)

    # Generate a Verification Certificate signed by the Root CA to prove CA ownership
    ./generate.sh verify-intermediate $CODE

    # Retrieve the Certificate ETAG which changed when the Verification Code was generated
    ETAG=$(az iot hub certificate show \
            --name "${ORGANIZATION}-intermediate" \
            --hub-name $HUB \
            --query etag -otsv)

    # Verify the CA Certificate with the Validation Certificate
    az iot hub certificate verify \
    --name "${ORGANIZATION}-intermediate" \
    --hub-name $HUB \
    --etag $ETAG \
    --path pki/certs/${ORGANIZATION}-verify.cert.pem \
    -oyaml
}

function create_chain()
{
  printf "\n"
  tput setaf 2; echo "Creating Chain Certificate" ; tput sgr0
  tput setaf 3; echo "--------------------------" ; tput sgr0

  # Concatinate the cert and pem to use as a chain
  cat "./pki/certs/$1.cert.pem" \
    "./pki/certs/$ORGANIZATION.intermediate.cert.pem" \
    "./pki/certs/$ORGANIZATION.root.ca.cert.pem" \
    > "./pki/certs/$1-chain.cert.pem"

  echo "    ./pki/certs/$1-chain.cert.pem"
}

function save_vault()
{
  printf "\n"
  tput setaf 2; echo "Saving to Vault" ; tput sgr0
  tput setaf 3; echo "---------------" ; tput sgr0

  # Import Certificate to the Key Vault
  az keyvault certificate import \
    --vault-name $VAULT \
    --name ${1} \
    --file "./pki/certs_pfx/${1}.cert.pfx" -oyaml
}

function generate_edge_certificate()
{
  if [ $# -ne 1 ]; then
    echo "Usage: <subjectName>"
    exit 1
  fi

  ./generate.sh edge $1
  create_chain $1

  ## Edge Devices have to have the Full Chain Certificates for Use
  openssl pkcs12 -inkey ./pki/private/${1}.key.pem \
                 -in ./pki/certs/${1}-chain.cert.pem \
                 -chain -CAfile ./pki/certs/${ORGANIZATION}.chain.ca.cert.pem \
                 -password pass:${INT_CA_PASSWORD} \
                 -export -out ./pki/certs_pfx/${1}-chain.cert.pfx

  printf "\n"
  tput setaf 2; echo "Saving to Vault" ; tput sgr0
  tput setaf 3; echo "---------------" ; tput sgr0
  az keyvault certificate import \
    --vault-name $VAULT \
    --name ${1} \
    --password ${INT_CA_PASSWORD} \
    --file "./pki/certs_pfx/${1}-chain.cert.pfx" -oyaml
}

function generate_device_certificate()
{
  if [ $# -lt 1 ]; then
    echo "Usage: device <deviceName>"
    exit 1
  fi

  ./generate.sh device $1
  create_chain $1
  save_vault $1
}

function generate_leaf_certificate()
{
  if [ $# -lt 1 ]; then
    echo "Usage: <subjectName>"
    exit 1
  fi

  ./generate.sh leaf $1
  create_chain $1
  save_vault $1
}

function clean_up() {
    # Remove the Private Key Folder
    printf "\n"
    tput setaf 2; echo "Removing Localhost Certificate Store" ; tput sgr0
    tput setaf 3; echo "------------------------------------" ; tput sgr0
    rm -rf ./pki
}


if [[ ${1} == "ca" ]]; then
    create_ca_certs
    archive_in_keyvault
elif [[ ${1} == "hub" ]]; then
    validate_to_hub
elif [[ ${1} == "edge" ]]; then
    generate_edge_certificate ${2}
elif [[ ${1} == "device" ]]; then
    generate_device_certificate ${2} ${3}
elif [[ ${1} == "leaf" ]]; then
    generate_leaf_certificate ${2} ${3}
elif [[ ${1} == "delete" ]]; then
    clean_up
else
    echo "Usage: ca                     # Creates new Root and Intermediate Certificate Authorities"
    echo "       hub                    # Loads and Validates Intermediate CA to the Iot Hub"
    echo "       edge     <deviceName>  # Creates a new edge device certificate"
    echo "       device   <deviceName>  # Creates a new device certificate"
    echo "       leaf     <deviceName>  # Creates a new leaf device certificate"
    echo "       delete                 # Removes all local PKI Files"
    exit 1
fi