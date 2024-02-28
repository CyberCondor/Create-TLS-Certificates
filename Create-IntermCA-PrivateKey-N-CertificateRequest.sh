#! /bin/bash

TLD=$(hostname -d | grep -o "\..*" | tr -d .)
DC=$(hostname -d | grep -o ".*\." | tr -d .)
Domain=$(hostname -d)
Server=$(hostname)
ServerFQDN=$(hostname -f)
ServerIPv4=$(hostname -I)
DigestAlgo="sha512"
CryptoAlgo="secp521r1"

CertificateSigningRequest="${Server}.INTERM-CA.CertificateSigningRequest.csr"
ExtFile="${DC}-INTERM_extfile.cnf"

currDate=$(date --iso-8601) # Get date keys and cert request is being made - format ISO-8601 e.g., 2023-07-30

RandFile="randfile_${ServerFQDN}_${currDate}.rand"
IntermCAPrivateKey="PRIVATE.INTERM-CA.KEY.${Server}.CRYPT.pem"

# Generate random contents in a file to seed the random number generator for the CA's private key using OpenSSL Rand
echo -e "\tMaking Random Data..."
for i in {1..369};do openssl rand -writerand randfile.rand${i} -base64;done 
for i in {1..369};do cat randfile.rand${i} >> ${RandFile};done
for i in {1..369};do rm randfile.rand${i};done
# Make the computer say something exciting for encouragement while you make certificates
espeak -k19 -p33 -s170 "bing bong - Done Making Random Data. Creating New Private Key For ${Server}" --stdout | aplay >/dev/null 2>&1
echo -e "\tDone Making Random Data"

# Make private key using OpenSSL with ECDSA and the random random data from prior
echo -e "\tMaking Private Key for ${Server}"
openssl ecparam -rand ${RandFile} -name ${CryptoAlgo} -genkey | openssl ec -aes-256-cbc -out ${IntermCAPrivateKey} 

# Change Private Key to Read only
chmod 400 ${IntermCAPrivateKey}
echo -e "\tChanged Private Key to Read Only"

###-------Private Key Generated ^^^ Create Cert Signing Request vvv

# Generate random contents in a file to seed the random number generator for the CA's private key using OpenSSL Rand
echo -e "\tMaking Random Data..."
rm ${RandFile}
for i in {1..369};do openssl rand -writerand randfile.rand${i} -base64;done 
for i in {1..369};do cat randfile.rand${i} >> ${RandFile};done
for i in {1..369};do rm randfile.rand${i};done
# Make the computer say something exciting for encouragement while you make certificates
espeak -k19 -p33 -s170 "bing bong - Done Making Random Data. Creating Certificate Signing Request For ${Server}" --stdout | aplay >/dev/null 2>&1
echo -e "\tDone Making Random Data"

echo -e "\tCreating Certificate Signing Request for ${Server}"
openssl req -new \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -subj "/C=US/O=${DC}/CN=${DC} Interm. CA" -multivalue-rdn \
    -key ${IntermCAPrivateKey} \
    -out ${CertificateSigningRequest}

echo "keyUsage = critical, digitalSignature, keyCertSign, cRLSign" > ${ExtFile}
echo "extendedKeyUsage = clientAuth, serverAuth" >> ${ExtFile}
echo "basicConstraints = critical, CA:TRUE, pathlen:0" >> ${ExtFile}

####---------------------
# Change CSR to Read only
chmod 400 ${CertificateSigningRequest}
echo -e "\tChanged CSR to Read Only"

#Clean Up
rm ${RandFile}
