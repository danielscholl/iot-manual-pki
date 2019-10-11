## Copyright (c) Microsoft. All rights reserved.
## Licensed under the MIT license. See LICENSE file in the project root for full license information.

###############################################################################
# This script demonstrates creating X.509 certificates for an Azure IoT Hub
# CA Cert deployment.
#
# These certs MUST NOT be used in production.  It is expected that production
# certificates will be created using a company's proper secure signing process.
# These certs are intended only to help demonstrate and prototype CA certs.
###############################################################################

home_dir="${0%/*}"
root_ca_dir="pki"
intermediate_ca_dir="pki"
openssl_root_config_file="root.cnf"
openssl_intermediate_config_file="intermediate.cnf"
root_ca_prefix="${ORGANIZATION}.root.ca"                ### SET FROM ENVRC
intermediate_ca_prefix="${ORGANIZATION}.intermediate"   ### SET FROM ENVRC
ca_chain_prefix="${ORGANIZATION}.chain.ca"

algorithm="genrsa"
key_bits_length="4096"
non_csa_key_bits_length="2048"
days_till_expire=360

COUNTRY="US"
STATE="TX"
LOCALITY="Dallas"
ORGANIZATION_NAME=$ORGANIZATION                         ### SET FROM ENVRC
root_ca_password=$ROOT_CA_PASSWORD                      ### SET FROM ENVRC
intermediate_ca_password=$INT_CA_PASSWORD               ### SET FROM ENVRC


function generate_root_ca()
{
    local common_name="Root CA Cert - ${ORGANIZATION}"
    local password_cmd=" -aes256 -passout pass:${root_ca_password} "

    openssl ${algorithm} \
            ${password_cmd} \
            -out ${root_ca_dir}/private/${root_ca_prefix}.key.pem \
            ${key_bits_length}
    [ $? -eq 0 ] || exit $?
    chmod 400 ${root_ca_dir}/private/${root_ca_prefix}.key.pem
    [ $? -eq 0 ] || exit $?

    printf "\n"
    tput setaf 2; echo "Creating the Root CA Certificate" ; tput sgr0
    tput setaf 3; echo "--------------------------------" ; tput sgr0

    password_cmd=" -passin pass:${root_ca_password} "
    export_password_cmd=" -passout pass:${root_ca_password} "

    openssl req \
            -new \
            -x509 \
            -config ${openssl_root_config_file} \
            ${password_cmd} \
            -key ${root_ca_dir}/private/${root_ca_prefix}.key.pem \
            -subj "/CN=${common_name}" \
            -days ${days_till_expire} \
            -sha256 \
            -extensions v3_ca \
            -out ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?

    printf "\n"
    tput setaf 2; echo "CA Root Certificate Generated At:" ; tput sgr0
    tput setaf 3; echo "--------------------------------" ; tput sgr0
    echo "    ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?

    printf "\n"
    tput setaf 2; echo "Create the Root Certificate PFX Certificate" ; tput sgr0
    tput setaf 3; echo "-------------------------------------------" ; tput sgr0
    openssl pkcs12 -in ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem \
            -inkey ${root_ca_dir}/private/${root_ca_prefix}.key.pem \
            ${password_cmd}  \
            ${export_password_cmd}  \
            -export -out ${root_ca_dir}/certs_pfx/${root_ca_prefix}.cert.pfx
    [ $? -eq 0 ] || exit $?
}



###############################################################################
# Generate Intermediate CA Cert
###############################################################################
function generate_intermediate_ca()
{
    local common_name="Intermediate CA Cert - ${ORGANIZATION}"
    local password_cmd=" -aes256 -passout pass:${intermediate_ca_password} "

    printf "\n"
    tput setaf 2; echo "Creating the Intermediate Device CA" ; tput sgr0
    tput setaf 3; echo "-----------------------------------" ; tput sgr0
    openssl ${algorithm} \
            ${password_cmd} \
            -out ${intermediate_ca_dir}/private/${intermediate_ca_prefix}.key.pem \
            ${key_bits_length}
    [ $? -eq 0 ] || exit $?

    chmod 400 ${intermediate_ca_dir}/private/${intermediate_ca_prefix}.key.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Creating the Intermediate Device CA CSR" ; tput sgr0
    tput setaf 3; echo "---------------------------------------" ; tput sgr0
    password_cmd=" -passin pass:${intermediate_ca_password} "

    openssl req -new -sha256 \
        ${password_cmd} \
        -config ${openssl_intermediate_config_file} \
        -subj "/CN=${common_name}" \
        -key ${intermediate_ca_dir}/private/${intermediate_ca_prefix}.key.pem \
        -out ${intermediate_ca_dir}/csr/${intermediate_ca_prefix}.csr.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Signing the Intermediate Certificate with Root CA Cert" ; tput sgr0
    tput setaf 3; echo "------------------------------------------------------" ; tput sgr0
    password_cmd=" -passin pass:${root_ca_password} "
    export_password_cmd=" -passout pass:${root_ca_password} "

    openssl ca -batch \
        -config ${openssl_root_config_file} \
        ${password_cmd} \
        -extensions v3_intermediate_ca \
        -days ${days_till_expire} -notext -md sha256 \
        -in ${intermediate_ca_dir}/csr/${intermediate_ca_prefix}.csr.pem \
        -out ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Verify signature of the Intermediate Device Certificate with Root CA" ; tput sgr0
    tput setaf 3; echo "--------------------------------------------------------------------" ; tput sgr0
    openssl verify \
            -CAfile ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem \
            ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Intermediate CA Certificate Generated At:" ; tput sgr0
    tput setaf 3; echo "-----------------------------------------" ; tput sgr0
    echo "    ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Create the Intermediate PFX Certificate" ; tput sgr0
    tput setaf 3; echo "---------------------------------------" ; tput sgr0
    password_cmd=" -passin pass:${intermediate_ca_password} "
    export_password_cmd=" -passout pass:${intermediate_ca_password} "
    openssl pkcs12 -in ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem \
            -inkey ${intermediate_ca_dir}/private/${intermediate_ca_prefix}.key.pem \
            ${password_cmd}  \
            ${export_password_cmd}  \
            -export -out ${intermediate_ca_dir}/certs_pfx/${intermediate_ca_prefix}.cert.pfx
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Create Root + Intermediate CA Chain Certificate" ; tput sgr0
    tput setaf 3; echo "-----------------------------------------------" ; tput sgr0
    cat ${intermediate_ca_dir}/certs/${intermediate_ca_prefix}.cert.pem \
        ${root_ca_dir}/certs/${root_ca_prefix}.cert.pem > \
        ${intermediate_ca_dir}/certs/${ca_chain_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${intermediate_ca_dir}/certs/${ca_chain_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?

    printf "\n"
    tput setaf 2; echo "Root + Intermediate CA Chain Certificate Generated At:" ; tput sgr0
    tput setaf 3; echo "------------------------------------------------------" ; tput sgr0
    echo "    ${intermediate_ca_dir}/certs/${ca_chain_prefix}.cert.pem"
}

###############################################################################
# Generate a Certificate for a device using specific openssl extension and
# signed with either the root or intermediate cert.
###############################################################################
function generate_device_certificate_common()
{
    local common_name="${1}"
    local device_prefix="${2}"
    local certificate_dir="${3}"
    local ca_password="${4}"
    local server_pfx_password="${PASSWORD}"
    local password_cmd=" -passin pass:${ca_password} "
    local openssl_config_file="${5}"
    local openssl_config_extension="${6}"
    local cert_type_diagnostic="${7}"

    printf "\n"
    tput setaf 2; echo "Creating ${cert_type_diagnostic} Certificate" ; tput sgr0
    tput setaf 3; echo "--------------------------------------------" ; tput sgr0
    openssl ${algorithm} \
            -out ${certificate_dir}/private/${device_prefix}.key.pem \
            ${non_ca_key_bits_length}
    [ $? -eq 0 ] || exit $?
    chmod 444 ${certificate_dir}/private/${device_prefix}.key.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Create the ${cert_type_diagnostic} Certificate Request" ; tput sgr0
    tput setaf 3; echo "------------------------------------------------------" ; tput sgr0
    openssl req -config ${openssl_config_file} \
        -key ${certificate_dir}/private/${device_prefix}.key.pem \
        -subj "/CN=${common_name}" \
        -new -sha256 -out ${certificate_dir}/csr/${device_prefix}.csr.pem
    [ $? -eq 0 ] || exit $?

    openssl ca -batch -config ${openssl_config_file} \
            ${password_cmd} \
            -extensions "${openssl_config_extension}" \
            -days ${days_till_expire} -notext -md sha256 \
            -in ${certificate_dir}/csr/${device_prefix}.csr.pem \
            -out ${certificate_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${certificate_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Verify signature of the ${cert_type_diagnostic} certificate with the signer" ; tput sgr0
    tput setaf 3; echo "---------------------------------------------------------------------------" ; tput sgr0
    openssl verify \
            -CAfile ${certificate_dir}/certs/${ca_chain_prefix}.cert.pem \
            ${certificate_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "${cert_type_diagnostic} Certificate Generated At:" ; tput sgr0
    tput setaf 3; echo "-------------------------------------------------" ; tput sgr0
    echo "    ${certificate_dir}/certs/${device_prefix}.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${certificate_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?


    printf "\n"
    tput setaf 2; echo "Create the ${cert_type_diagnostic} PFX Certificate" ; tput sgr0
    tput setaf 3; echo "--------------------------------------------------" ; tput sgr0
    openssl pkcs12 -in ${certificate_dir}/certs/${device_prefix}.cert.pem \
            -inkey ${certificate_dir}/private/${device_prefix}.key.pem \
            -password pass:${server_pfx_password} \
            -export -out ${certificate_dir}/certs_pfx/${device_prefix}.cert.pfx
    [ $? -eq 0 ] || exit $?

    echo "    ${certificate_dir}/certs_pfx/${device_prefix}.cert.pfx"
    [ $? -eq 0 ] || exit $?
}

###############################################################################
#  Creates required directories and removes left over cert files.
#  Run prior to creating Root CA; after that these files need to persist.
###############################################################################
function prepare_filesystem()
{
    if [ ! -f ${openssl_root_config_file} ]; then
        echo "Missing file ${openssl_root_config_file}"
        exit 1
    fi

    if [ ! -f ${openssl_intermediate_config_file} ]; then
        echo "Missing file ${openssl_intermediate_config_file}"
        exit 1
    fi

    rm -rf ${root_ca_dir}/csr
    rm -rf ${root_ca_dir}/private
    rm -rf ${root_ca_dir}/certs
    rm -rf ${root_ca_dir}/certs_pfx
    rm -rf ${root_ca_dir}/self
    rm -rf ${root_ca_dir}/newcerts

    mkdir -p ${root_ca_dir}/csr
    mkdir -p ${root_ca_dir}/private
    mkdir -p ${root_ca_dir}/certs
    mkdir -p ${root_ca_dir}/certs_pfx
    mkdir -p ${root_ca_dir}/self
    mkdir -p ${root_ca_dir}/newcerts

    rm -f ${root_ca_dir}/index.txt
    touch ${root_ca_dir}/index.txt

    rm -f ${root_ca_dir}/serial
    echo 01 > ${root_ca_dir}/serial
}

###############################################################################
# Generates a root and intermediate certificate for CA certs.
###############################################################################
function initial_cert_generation()
{
    prepare_filesystem
    generate_root_ca
    generate_intermediate_ca
}

###############################################################################
# Generate a certificate for a leaf device
# signed with either the root or intermediate cert.
###############################################################################
function generate_leaf_certificate()
{
    local common_name="${1}"
    local device_prefix="${2}"
    local certificate_dir="${3}"
    local ca_password="${4}"
    local openssl_config_file="${5}"

    generate_device_certificate_common "${common_name}" \
                                       "${device_prefix}" \
                                       "${certificate_dir}" \
                                       "${ca_password}" \
                                       "${openssl_config_file}" \
                                       "server_cert" \
                                       "Leaf Device"
}

###############################################################################
# Generates a certificate for verification, chained directly to the root.
###############################################################################
function generate_verification_certificate()
{
    local ca_dir=${root_ca_dir}
    local ca_password=${root_ca_password}
    local openssl_config_file=${openssl_root_config_file}

    if [ "$2" ]; then
      ca_dir=${intermediate_ca_dir}
      ca_password=${intermediate_ca_password}
      openssl_config_file=${openssl_intermediate_config_file}
    fi

    rm -f ./pki/private/${ORGANIZATION}-verify.key.pem
    rm -f ./pki/certs/${ORGANIZATION}-verify.cert.pem
    rm -f ./pki/certs_pfx/${ORGANIZATION}-verify.cert.pfx
    rm -f ./pki/csr/${ORGANIZATION}-verify.csr.pem
    grep -v ${1} ./pki/index.txt > ./pki/index.txt.old && cp ./pki/index.txt.old ./pki/index.txt

    generate_leaf_certificate "${1}" \
                              "${ORGANIZATION}-verify" \
                              ${ca_dir} \
                              ${ca_password} \
                              ${openssl_config_file}
}

###############################################################################
# Generates a certificate for a device, chained to the intermediate.
###############################################################################
function generate_device_certificate()
{
    if [ $# -ne 1 ]; then
        echo "Usage: <subjectName>"
        exit 1
    fi

    local device_prefix="new-device"
    if [ "$1" ]; then
      device_prefix=$1
    fi

    rm -f ./pki/csr/${device_prefix}.csr.pem
    rm -f ./pki/private/${device_prefix}.key.pem
    rm -f ./pki/certs/${device_prefix}.cert.pem
    rm -f ./pki/certs_pfx/${device_prefix}.cert.pfx
    rm -f ./pki/certs/${device_prefix}-full-chain.cert.pem
    grep -v ${device_prefix} ./pki/index.txt > ./pki/index.txt.old && cp ./pki/index.txt.old ./pki/index.txt

    generate_device_certificate_common ${device_prefix} \
                                       ${device_prefix} \
                                       ${intermediate_ca_dir} \
                                       ${intermediate_ca_password} \
                                       ${openssl_intermediate_config_file} \
                                       "server_cert" \
                                       "Device"
}


################################################################################
# Generates a certificate for an Edge server, chained to the device intermediate.
################################################################################
function generate_edge_device_certificate()
{
    if [ $# -ne 1 ]; then
      echo "Usage: <subjectName>"
      exit 1
    fi

    local device_prefix="new-device"
    if [ "$1" ]; then
      device_prefix=$1
    fi

    rm -f ./pki/csr/${device_prefix}.csr.pem
    rm -f ./pki/private/${device_prefix}.key.pem
    rm -f ./pki/certs/${device_prefix}.cert.pem
    rm -f ./pki/certs_pfx/${device_prefix}.cert.pfx
    rm -f ./pki/certs/${device_prefix}.-full-chain.cert.pem
    grep -v ${device_prefix} ./pki/index.txt > ./pki/index.txt.old && cp ./pki/index.txt.old ./pki/index.txt

    # Note: Appending a '.ca' to the common name is useful in situations
    # where a user names their hostname as the edge device name.
    # By doing so we avoid TLS validation errors where we have a server or
    # client certificate where the hostname is used as the common name
    # which essentially results in "loop" for validation purposes.
    generate_device_certificate_common "${1}.ca" \
                                       "${device_prefix}.ca" \
                                       ${intermediate_ca_dir} \
                                       ${intermediate_ca_password} \
                                       ${openssl_intermediate_config_file} \
                                       "v3_intermediate_ca" \
                                       "Edge CA"
}

################################################################################
# Generates an identity certificate for an Edge, chained to the intermediate.
################################################################################
function generate_edge_identity_certificate()
{
    if [ $# -ne 1 ]; then
      echo "Usage: <subjectName>"
      exit 1
    fi

    local device_prefix="new-device"
    if [ "$1" ]; then
      device_prefix=$1
    fi

    rm -f ./pki/csr/${device_prefix}.csr.pem
    rm -f ./pki/private/${device_prefix}.key.pem
    rm -f ./pki/certs/${device_prefix}.cert.pem
    rm -f ./pki/certs_pfx/${device_prefix}.cert.pfx
    rm -f ./pki/certs/${device_prefix}.-full-chain.cert.pem
    grep -v ${device_prefix} ./pki/index.txt > ./pki/index.txt.old && cp ./pki/index.txt.old ./pki/index.txt

    # Note: Appending a '.ca' to the common name is useful in situations
    # where a user names their hostname as the edge device name.
    # By doing so we avoid TLS validation errors where we have a server or
    # client certificate where the hostname is used as the common name
    # which essentially results in "loop" for validation purposes.
    generate_device_certificate_common "${1}" \
                                       "${device_prefix}.identity" \
                                       ${intermediate_ca_dir} \
                                       ${intermediate_ca_password} \
                                       ${openssl_intermediate_config_file} \
                                       "usr_cert" \
                                       "Edge Identity"
}

###############################################################################
# Generates a certificate for a leaf device, chained to the intermediate.
###############################################################################
function generate_leaf_device_certificate()
{
    if [ $# -ne 1 ]; then
      echo "Usage: <subjectName>"
      exit 1
    fi

    local device_prefix="new-leaf"
    if [ "$1" ]; then
      device_prefix=$1
    fi

    rm -f ./pki/csr/${device_prefix}.csr.pem
    rm -f ./pki/private/${device_prefix}.key.pem
    rm -f ./pki/certs/${device_prefix}.cert.pem
    rm -f ./pki/certs_pfx/${device_prefix}.cert.pfx
    rm -f ./pki/certs/${device_prefix}.-full-chain.cert.pem
    grep -v ${device_prefix} ./pki/index.txt > ./pki/index.txt.old && cp ./pki/index.txt.old ./pki/index.txt

    generate_leaf_certificate "${1}" \
                              ${device_prefix} \
                              ${intermediate_ca_dir} \
                              ${intermediate_ca_password} \
                              ${openssl_intermediate_config_file}
}


cd $home_dir

if [ "${1}" == "ca" ]; then
    initial_cert_generation
elif [ "${1}" == "verify" ]; then
    generate_verification_certificate "${2}"
elif [ "${1}" == "verify-intermediate" ]; then
    generate_verification_certificate "${2}" "intermediate"
elif [ "${1}" == "device" ]; then
    generate_device_certificate "${2}"
elif [ "${1}" == "edge" ]; then
    generate_edge_device_certificate "${2}"
    generate_edge_identity_certificate "${2}"
elif [ "${1}" == "leaf" ]; then
    generate_leaf_device_certificate "${2}"
else
    echo "Usage: ca                                 # Creates a new root and intermediate certificates"
    echo "       verify <subjectName>               # Creates a verification certificate, signed with <subjectName>"
    echo "       verify-intermediate <subjectName>  # Creates a verification certificate, signed with <subjectName>"
    echo "       device <subjectName>               # Creates a device certificate, signed with <subjectName>"
    echo "       edge <subjectName>                 # Creates an edge device certificate, signed with <subjectName>"
    echo "       leaf <subjectName>                 # Creates a leaf device certificate, signed with <subjectName>"
    exit 1
fi
