#!/bin/bash

helpFunction()
{
    echo ""
    echo "Usage: $0 -p PROJECT_ID"
    echo -e "\t-p Project Id of the google cloud project that you want to integrate"
    echo ""
    exit 1 # Exit script after printing help
}

while getopts ":p:" opt; do
    case $opt in
        p) GCP_PROJECT_ID="$OPTARG"
        ;;
        \?) echo "Invalid flag -$OPTARG" >&2;
            helpFunction
            exit 1
        ;;
    esac
    
    case $OPTARG in
        -*) echo "flag $opt needs a valid porject Id";
            helpFunction
            exit 1
        ;;
    esac
done

CES_SERVICE_ACCOUNT="ces-service-account"

CES_ROLE_NAME="ces_freemium_role"

ROLE_YML="ces_service_account_role.yml"



if [ -z "$GCP_PROJECT_ID" ] || [ -z "$CES_SERVICE_ACCOUNT" ]; then
    echo "There is a problem with project Id, No Id passed as argument"
    echo "Please pass project Id with -p flag"
    echo "Project ID: ${GCP_PROJECT_ID}"
    exit 1
fi


curl https://raw.githubusercontent.com/sai-naveen-kumar/azure-policy/main/ces-service-role.yaml -o ${ROLE_YML}

gcloud services enable servicemanagement

gcloud iam roles create ${CES_ROLE_NAME} --project ${GCP_PROJECT_ID} --file ${ROLE_YML} -q >&1

gcloud iam service-accounts create ${CES_SERVICE_ACCOUNT} \
--display-name ${CES_SERVICE_ACCOUNT} \
--description="account used by CE to execute scripts"

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member serviceAccount:${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
--role projects/${GCP_PROJECT_ID}/roles/${CES_ROLE_NAME} --condition=None

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member serviceAccount:${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
--role roles/iam.serviceAccountUser --condition=None

gcloud iam service-accounts keys create ces_role_key.json \
--iam-account ${CES_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com
