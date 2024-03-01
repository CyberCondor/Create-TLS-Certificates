#! /bin/bash

CertificateSigningRequest=$1
ClientFQDN=$2
ExtFile=$3
if [ ! -f "$CertificateSigningRequest" ];
then
	echo "$CertificateSigningRequest file does not exist."
    exit 1
fi
if [ ! -f "$ExtFile" ];
then
	echo "$ExtFile file does not exist."
    exit 1
fi

ServerFQDN=$(hostname -f)
DigestAlgo="sha512"
ValidDaysClient="2920" # this is the Interm CA cert - 2920 Days = 8 years
ValidDaysServer="3285" # this is the Root CA cert - 3285 Days = 9 Years

currDate=$(date --iso-8601) # Get date keys and cert request is being made - format ISO-8601 e.g., 2023-07-30

CA_KEY="PRIVATE.ROOT-CA.KEY.${ServerFQDN}.CRYPT.pem"
CA_Cert="ROOT-CA.Cert.${ServerFQDN}_ValidFor${ValidDaysServer}.pem"

RandFile="randfile_${ServerFQDN}_${currDate}.rand"

SignedCertificate="${ClientFQDN}.INTERM-CA.SignedCertificate_${currDate}_ValidFor${ValidDaysClient}.pem" # <- This goes back to customer
FullChainCertificate="${ClientFQDN}.INTERM-CA.FullChainCert_ValidFor${ValidDaysClient}.pem" # <- This goes back to customer

# Generate random contents in a file to seed the random number generator for the Certificate Signing using OpenSSL Rand
echo -e "\tMaking Random Data..."
for i in {1..963};do openssl rand -writerand randfile.rand${i} -base64;done 
for i in {1..963};do cat randfile.rand${i} >> ${RandFile};done
for i in {1..963};do rm randfile.rand${i};done
# Make the computer say something exciting for encouragement while you make certificates
espeak -k19 -p33 -s170 "Done Making Random Data. Signing ${ClientFQDN}'s Certificate Signing Request..." --stdout | aplay >/dev/null 2>&1
echo -e "\tDone Making Random Data"

####---------------------
echo -e "\tCA is Signing Certificate Request:" 
openssl x509 -req \
    -rand ${RandFile} \
    -${DigestAlgo} \
    -days ${ValidDaysClient} \
    -extfile ${ExtFile} \
    -in ${CertificateSigningRequest} \
    -CA ${CA_Cert} \
    -CAkey ${CA_KEY} \
    -CAcreateserial \
    -out ${SignedCertificate}

# Create Certificate Chain by combining CA certificate and Server certificate
cat ${SignedCertificate} >> ${FullChainCertificate}
cat ${CA_Cert} >> ${FullChainCertificate}
echo -e "\tCreated Certificate chain by combining CA cert and Server cert."

# Change Certificates to Read only
chmod 400 ${SignedCertificate}
echo -e "\tChanged Newly Signed Certificate to Read Only"
chmod 400 ${FullChainCertificate}
echo -e "\tChanged Full-Chain Certificate to Read Only"

#Clean Up
rm ${RandFile}
rm -f ${CertificateSigningRequest}
rm -f ${ExtFile}

espeak -k19 -p33 -s170 "Tell ${ClientFQDN} to enjoy their CERTIFICATE. 'Till next time, $(hostname). Goodbye!" --stdout | aplay >/dev/null 2>&1

echo -e "\tResults:"
#Show Results of new server cert
openssl x509 -in ${FullChainCertificate} -text
openssl x509 -in ${CA_Cert} -text
