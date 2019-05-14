# iot-manual-pki

The purpose of this solution is to be able to test x509 certificates and x509 certs signed by a CA without using a public signing authority.  It uses a heavily modified base script provided in the azure-iot-sdk

 using x509 certs signed by an Intermediate CA.  It uses the base script provided in the [azure-iot-sdk](https://github.com/Azure/azure-iot-sdk-c/blob/master/tools/CACertificates/CACertificateOverview.md) but heavily modified which is _not recommended_ to be used for production scenarios but is helpful for testing purposes. 

 __PreRequisites__

Requires the use of [direnv](https://direnv.net/).

Requires the use of [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

Requires the use of [OpenSSL](https://www.openssl.org).


## Environment Variables

Copy the `.envrc_sample` environment setting file and modify as desired in the root directory to: `.envrc`

Default Environment Settings

| Parameter            | Default                              | Description                              |
| -------------------- | ------------------------------------ | ---------------------------------------- |
| _ORGANIZATION_       | myorg                                | CA Organization Name                     |
| _ROOT_CA_PASSWORD_   | certPassword                         | Certificate Password for Root CA         |
| _INT_CA_PASSWORD_    | certPassword                         | Certificate Password for Intermediate CA |
| _VAULT_              | vault                                | Vault Name to store Certificates         |
| _HUB_                | hub                                  | Hub Name to upload Certificate to        |

> The default ORGANIZATION name is `myorg`.  These files have the reference to the organization that can be renamed as necessary.
  - .envrc
  - root.cnf
  - intermediate.cnf

## Create and Upload Certificates

```
    Usage: ca                     # Creates new Root and Intermediate Certificate Authorities
           device   <deviceName>  # Creates a new device certificate
           edge     <deviceName>  # Creates a new edge device certificate
           leaf     <deviceName>  # Creates a new leaf device certificate
           get      <deviceName>  # Retrieves a device certificate <deviceName> (optional)
           hub                    # Loads and Validates Intermediate CA to the Iot Hub
           delete                 # Removes all local PKI Files
```

> [Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) is an excellent tool to perform these actions on as CloudDrive is Redundant Storage.