#! /bin/bash

TLD=$(hostname -d | grep -o "\..*" | tr -d .)
DC=$(hostname -d | grep -o ".*\." | tr -d .)
Domain=$(hostname -d)
ServerFQDN=$(hostname -f)
DigestAlgo="sha512"
CryptoAlgo="secp521r1"
ValidDays="3285" # 3285 Days = 9 Years

currDate=$(date --iso-8601) # Get date keys and cert request is being made - format ISO-8601 e.g., 2023-07-30

RandFile="randfile_${ServerFQDN}_${currDate}.rand"
RootCA_PRIVATEKEY="PRIVATE.ROOT-CA.KEY.${ServerFQDN}.CRYPT.pem"

SelfSignedRootCA_Certificate="ROOT-CA.Cert.${ServerFQDN}_ValidFor${ValidDays}.pem"

# Generate random contents in a file to seed the random number generator for the CA's private key using OpenSSL Rand
echo -e "\tMaking Random Data..."
for i in {1..369};do openssl rand -writerand randfile.rand${i} -base64;done 
for i in {1..369};do cat randfile.rand${i} >> ${RandFile};done
for i in {1..369};do rm randfile.rand${i};done
# Make the computer say something exciting for encouragement while you make certificates
espeak -k19 -p33 -s170 "Done Making Random Data. Creating New Root Certificate Authority Private Key. ${DC}... is the Boss!" --stdout | aplay >/dev/null 2>&1
echo -e "\tDone Making Random Data.."

# Make private key using OpenSSL with ECDSA and the random random data from prior
echo -e "\tMaking Private Key for ${DC}"
echo -e "\tThe following is asking you to enter a password for your Root CA PRIVATE KEY."
openssl ecparam -rand ${RandFile} -name ${CryptoAlgo} -genkey | openssl ec -aes-256-ctr -out ${RootCA_PRIVATEKEY}

# Change Private Key to Read only
chmod 400 ${RootCA_PRIVATEKEY}
echo -e "\tChanged Private Key to Read Only"

# Generate random contents in a file to seed the random number generator for the CA's Certificate using OpenSSL Rand
echo -e "\tMaking Random Data..."
rm ${RandFile}
for i in {1..369};do openssl rand -writerand randfile.rand${i} -base64;done 
for i in {1..369};do cat randfile.rand${i} >> ${RandFile};done
for i in {1..369};do rm randfile.rand${i};done
# Make the computer say something exciting for encouragement while you make certificates
espeak -k19 -p33 -s170 "Done Making Random Data. Creating New Root Certificate Authority. ${DC}... is the Boss!" --stdout | aplay >/dev/null 2>&1
echo -e "\tDone Making Random Data.."

# Generate new self-signed x.509 certificate that is valid for a specific amount of time using the defined cryptographic algorithms
echo -e "\tCreating new self signed Root CA Certificate"
echo -e "\t*Need Root CA Private Key Password during this step."
openssl req -new -x509 \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=${DC} Root CA" -multivalue-rdn \
    -addext "keyUsage = critical, digitalSignature, keyCertSign, cRLSign" \
    -addext "basicConstraints = critical, CA:TRUE, pathlen:1" \
    -days ${ValidDays} \
    -key ${RootCA_PRIVATEKEY} \
    -out ${SelfSignedRootCA_Certificate}

# If the client trusts the root CA, then any cert signed by the root CA will also be trusted by the client
###----------------------------

# Change Root CA to Read only
chmod 400 ${SelfSignedRootCA_Certificate}
echo -e "\tChanged Root CA to Read Only"

#Clean Up
rm ${RandFile}

echo -e "\tResults:"
# Show Results of new Cert
openssl x509 -in ${SelfSignedRootCA_Certificate} -text

echo -e "\t ^ Can be found here -> $(pwd)"
