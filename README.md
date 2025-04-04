# Create-TLS-Certificates
Create Certificate Chains Using OpenSSL

### Self-Signed Certificate

- **Private Key Creation**: The first step for any certificate authority (CA) or entity wishing to secure communications is to generate a private key. This private key is used to create digital signatures that prove the identity of the certificate holder.
- **Self-Signed Certificate**: A self-signed certificate is signed with the entity's own private key. Point here is that for self-signed certificates, the issuer and the subject are the same entity. This means the certificate is generated and signed by the entity itself, using its private key to sign the certificate. This process establishes the root of trust in environments where the entity acts as its own CA.

### Certificate Signing Request (CSR)

- **CSR Creation**: When an entity (like an Intermediate CA or an end entity like a server) wants to obtain a certificate signed by another authority (like a Root CA or an Intermediate CA), it generates a CSR. The CSR includes the public key of the entity and other information such as the organization name and common name (domain name).
- **Signing the CSR**: The CSR includes a signature created using the entity's private key. This signature helps the CA verify that the requester indeed has access to the private key corresponding to the public key in the CSR. The purpose of this signature is to prove ownership of the private key and the authenticity of the request.


- A self-signed certificate is generated by an entity and signed with its own private key, making the issuer and subject the same.
- A CSR is created by an entity to request a certificate from a CA. It includes a signature generated with the entity's private key. This signature is for proving ownership of the private key and the authenticity of the request to the CA. The CA then issues a certificate signed with the CA's private key.


# Process Overview
#### Step 1 - The Root CA
If looking for a simple self signed certificate, this is your only stop.

An 'authority' (Root CA):
1. Creates a private key
2. Creates a self-signed certificate - signed by their private key

#### Step 2 - The Intermediate CA
An intermediate 'authority' (Intermediate CA):
1. Creates a private key
2. Creates a certificate request signed by their private key
3. Creates an ext-file that denotes the purpose of the certificate
4. Sends their certificate request and ext-file to the Root CA

The 'Root CA'
1. Validates the certificate request and extensions received from the Intermediate CA
2. Signs the certificate request with their self signed certificate and their private key
3. Returns the signed certificate back to the Intermediate CA

The Root CA and Intermediate CA are now set up.

#### Step 3 - The Client
A 'Client'
1. Creates a private key
2. Creates a certificate request signed by their private key
3. Creates an ext-file that denotes the purpose of the certificate they are requesting
4. Sends their certificate request and ext-file to a signing authority

The 'Signing Authority' - Intermediate CA
1. Validates the certificate request and extensions received from the client.
2. Signs the certificate request with their signed (by the Root CA) certificate and private key
3. Returns the signed certificate back (and hopefully certificate chain) back to the client

---
# Example Variables
```BASH
TLD=$(hostname -d | grep -o "\..*" | tr -d .)
DC=$(hostname -d | grep -o ".*\." | tr -d .)
Domain=$(hostname -d)
Server=$(hostname)
ServerFQDN=$(hostname -f)
ServerIPv4=$(hostname -I)
DigestAlgo="sha512"
CryptoAlgo="secp521r1"
```

# Create-RootCA-PrivateKey-N-RootCA-Certificate
#### Create Private Key and Encrypt It
```BASH
openssl ecparam \
	-rand ${RandFile} \
	-name ${CryptoAlgo} \
	-genkey | openssl ec -aes-256-ctr -out ${RootCA_PRIVATEKEY}
```

#### Create Self Signed Cert
The Root CA Cert is always self signed
The x509 argument in OpenSSL denotes self signed Root CA
CA true & path length 1 to allow for INTERM. CA 
The Root CA should only sign Intermediate CA signing requests and be used to verify the authenticity of Intermediate certificates that validate server certificates.
```BASH
openssl req -new -x509 \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=${DC} Root CA" -multivalue-rdn \
    -addext "keyUsage = critical, digitalSignature, keyCertSign, cRLSign" \
    -addext "basicConstraints = critical, CA:TRUE, pathlen:1" \
    -days ${ValidDays} \
    -key ${RootCA_PRIVATEKEY} \
    -out ${SelfSignedRootCA_Certificate}
```

---
# Create-IntermCA-PrivateKey-N-CertificateRequest
#### Create Private Key and Encrypt It
```BASH
openssl ecparam \
	-rand ${RandFile} \
	-name ${CryptoAlgo} \
	-genkey | openssl ec -aes-256-ctr -out ${IntermCAPrivateKey}
```

#### Create Certificate Request
INTERM. CA Cert Request - (CA true & path length 0)
A certificate request and ext-file is created to pass over to the Root CA.
The Root CA will validate what the client is requesting and the certificate request before signing it.
An ext-file is required for certificate signing requests, as add-ext appears to only work with self signed certs.
```BASH
openssl req -new \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=${DC} Interm. CA" -multivalue-rdn \
    -key ${IntermCAPrivateKey} \
    -out ${CertificateSigningRequest}

echo "keyUsage = critical, digitalSignature, keyCertSign, cRLSign" > ${ExtFile}
echo "extendedKeyUsage = clientAuth, serverAuth" >> ${ExtFile}
echo "basicConstraints = critical, CA:TRUE, pathlen:0" >> ${ExtFile}
```

---
# Create-Domain-PrivateKey-N-DomainWildcard-CertificateRequest
#### Create Private Key and Encrypt It
```BASH
openssl ecparam \
	-rand ${RandFile} \
	-name ${CryptoAlgo} \
	-genkey | openssl ec -aes-256-ctr -out ${DomainPrivateKey}
```

#### Create Domain Wildcard Certificate Request
The CA must validate that the signing requester owns the domain for the certificate they are requesting to be signed.
Domain Wildcard Cert Request:
```BASH
openssl req -new \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=*.${Domain}" -multivalue-rdn \
    -key ${DomainPrivateKey} \
    -out ${CertificateSigningRequest}

echo "subjectAltName=DNS:*.${Domain}" > ${ExtFile}
echo "keyUsage = critical, digitalSignature, keyEncipherment" >> ${ExtFile}
echo "extendedKeyUsage = clientAuth, serverAuth" >> ${ExtFile}
echo "basicConstraints = critical, CA:FALSE" >> ${ExtFile}
```

---
# Create-Server-PrivateKey-N-ServerSpecific-CertificateRequest
#### Create Private Key and Encrypt It
```BASH
openssl ecparam \
	-rand ${RandFile} \
	-name ${CryptoAlgo} \
	-genkey | openssl ec -aes-256-ctr -out ${ServerPrivateKey}
```


#### Create Server Specific Certificate Request
Include IP address of server in ext-file passed to CA
The CA must validate that the signing requester owns the domain for the certificate they are requesting to be signed.
Server FQDN specific Cert Request:
```BASH
openssl req -new \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=${ServerFQDN}" -multivalue-rdn \
    -key ${ServerPrivateKey} \
    -out ${CertificateSigningRequest}

echo "subjectAltName=DNS:${ServerFQDN},IP:${ServerIPv4}" > ${ExtFile}
echo "keyUsage = critical, digitalSignature, keyEncipherment" >> ${ExtFile}
echo "extendedKeyUsage = clientAuth, serverAuth" >> ${ExtFile}
echo "basicConstraints = critical, CA:FALSE" >> ${ExtFile}
```


