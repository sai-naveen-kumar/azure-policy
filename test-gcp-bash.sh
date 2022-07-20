#!/bin/bash	
# Dynamic params
GCP_PROJECT_ID="versatile-gist-328905"

CES_SERVICE_ACCOUNT="ces-service-account"

CES_ROLE_NAME="ces_freemium_role"

ROLE_YML="ces_service_account_role.yml"



if [ -z "$GCP_PROJECT_ID" ] || [ -z "$CES_SERVICE_ACCOUNT" ]; then
	echo "There was a problem with one of the arguments:"
	echo "Project ID: ${GCP_PROJECT_ID}"
	echo "Service account name: ${CES_SERVICE_ACCOUNT}"
	exit -1
fi


curl https://raw.githubusercontent.com/sai-naveen-kumar/azure-policy/main/ces-service-role.yaml -o ${ROLE_YML}

gcloud services enable servicemanagement

gcloud iam roles create ${CES_ROLE_NAME} --project ${GCP_PROJECT_ID} --file ${ROLE_YML} -q

gcloud iam service-accounts create ${CES_SERVICE_ACCOUNT} --display-name ${CES_SERVICE_ACCOUNT}

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
 --member serviceAccount:${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
 --role projects/${GCP_PROJECT_ID}/roles/${CES_ROLE_NAME} --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
 --member serviceAccount:${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
 --role roles/iam.serviceAccountUser --condition=None

gcloud iam service-accounts keys create ces_role_key.json \
  --iam-account ${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com

