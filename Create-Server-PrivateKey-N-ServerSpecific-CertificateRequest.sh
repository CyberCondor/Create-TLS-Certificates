#! /bin/bash

TLD=$(hostname -d | grep -o "\..*" | tr -d .)
DC=$(hostname -d | grep -o ".*\." | tr -d .)
Domain=$(hostname -d)
Server=$(hostname)
ServerFQDN=$(hostname -f)
ServerIPv4=$(hostname -I)
DigestAlgo="sha512"
CryptoAlgo="secp521r1"

CertificateSigningRequest="${ServerFQDN}.CertificateSigningRequest.csr"
ExtFile="${ServerFQDN}_extfile.cnf"

currDate=$(date --iso-8601) # Get date keys and cert request is being made - format ISO-8601 e.g., 2023-07-30

RandFile="randfile_${ServerFQDN}_${currDate}.rand"
ServerPrivateKey="Private.${Server}.Key_${currDate}.pem"

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
openssl ecparam -rand ${RandFile} -name ${CryptoAlgo} -genkey -out ${ServerPrivateKey} # | openssl ec -aes-256-cbc -out ${ServerPrivateKey} 

# Change Private Key to Read only
chmod 400 ${ServerPrivateKey}
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

# Certificate request of server signed with server's private key
echo -e "\tCreating Certificate Signing Request for ${Server}"
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

####---------------------
# Change CSR and to Read only
chmod 400 ${CertificateSigningRequest}
echo -e "\tChanged CSR to Read Only"

#Clean Up
rm ${RandFile}
