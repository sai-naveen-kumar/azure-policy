#!/bin/bash

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BICyan='\033[1;96m'
SUBSCRIPTIONS=""
SUBSCRIPTION_ID=""
app_id=""
CREDENTIALS=""
ROLE_DEFINITION_URL="https://raw.githubusercontent.com/sai-naveen-kumar/azure-policy/main/ces-app-role.json"


confirm_jq_installed() {
  if ! command -v jq &> /dev/null; then
    printf "${RED}JQ not installed\nPlease install and re-run.${NC}\n" && exit 1
  fi
}

confirm_az_login() {
  if ! $(az account show &> /dev/null); then
    printf "${GREEN}Logging in:${NC}\n" && az login
  fi
}


extension_auto_install() {
  az config set extension.use_dynamic_install=yes_without_prompt
}

is_valid_subscription() {
  valid_subscription=$(echo "${subscriptions}" | jq --arg sub "${SUBSCRIPTION_ID}" '.[] | select(.subscriptionId == $sub)')
  if [[ -z "${valid_subscription}" ]]; then
    printf "${RED}Not a valid subscription ID: ${SUBSCRIPTION_ID}${NC}\n" && exit 1
  fi
}


handle_multiple_subscriptions() {
  printf "${GREEN}Pick a key number instead to select a specific one(accept only intergers)${NC}\n"
  read -p "Hit any other key to abort: " -n 1 -r
    echo
    if [[ $REPLY -ge 0 ]] && [[ $REPLY -le ${number_of_subscriptions} ]]; then
      choice=$(echo "${subscriptions}" | jq --argjson sub_id "$REPLY" '.[$sub_id].displayName')
      if [[ "${choice}" == "null" ]]; then
        printf "${RED}Bad choice: ${REPLY}${NC}\n" && exit 1
      else
        printf "${GREEN}Using subscription ${REPLY}: ${choice} ${NC}\n"
        Subscription_name="${choice}"
      fi
      SUBSCRIPTION_ID=$(echo "${subscriptions}" | jq -j --argjson sub_id "$REPLY" '.[$sub_id].subscriptionId')
    else
      printf "${RED}No subscription chosen, aborting.${NC}\n" && exit 0
    fi
}




get_subscriptions() {
  subscriptions=$(az account subscription list)
  if [ "${SUBSCRIPTION_ID}" != "" ]; then
    is_valid_subscription
  fi

  number_of_subscriptions=$(echo "${subscriptions}" | jq length)
  if [[ "${number_of_subscriptions}" == "1" ]]; then
    subscription=$(echo "${subscriptions}" | jq -j '.[0] | {displayName, subscriptionId}')
    printf "${YELLOW}Using subscription: ${subscription}${NC}\n"
    Subscription_name=$(echo "${subscriptions}" | jq -j '.[0].displayName')
    SUBSCRIPTION_ID=$(echo "${subscriptions}" | jq -j '.[0].subscriptionId')
  elif [[ "${number_of_subscriptions}" == "0" ]]; then
    printf "${RED}Couldn't find existing subscriptions.${NC}\n" && exit 1
  else
    multiple=$(echo "${subscriptions}" |
      jq -j '. | to_entries[] | .value.displayName as $name | .value.subscriptionId as $id | {key, $name, $id}')
    printf "${YELLOW}Multiple subscriptions found:\n${BICyan}${multiple}${NC}\n"
    handle_multiple_subscriptions "${subscriptions}"
  fi
}




get_role_definition() {
  curl -s "${ROLE_DEFINITION_URL}"
}


print_outputs() {
  delimiter="//"
  app_id="${app_id}"
  tenant_id="${tenant_id}"
  secret="${secret}"
  sub_id="${SUBSCRIPTION_ID}"
  sub_name="${Subscription_name}"
  printf "${BICyan}${tenant_id}${delimiter}${sub_id}${delimiter}${sub_name}${delimiter}${app_id}${delimiter}${secret}${NC}${delimiter}"
}

print_outputs_headline() {
  printf "${YELLOW}********************************************************${NC}\n"
  printf "${YELLOW}Provide the string(s) below to complete the integration:${NC}\n"
}

compose_role_definition() {
  role_definition=$(get_role_definition)
  echo "${role_definition}" \
    | jq --arg sub "/subscriptions/${SUBSCRIPTION_ID}" '.AssignableScopes[0] |= $sub' \
    |jq '.Name = "ces-freemium-app-role"'
}

create_custom_role() {
  role=$1
  az role definition create \
    --role-definition "${role}" | jq -j '.roleName'
} 

assign_role_to_sp() {
  assignee=$1
  role_name=$2
  az role assignment create \
    --assignee "${assignee}" \
    --role "${role_name}" \
    --subscription "${SUBSCRIPTION_ID}"
}

create_assign_role(){
updated_role_definition=$(compose_role_definition)
role_name=$(create_custom_role "${updated_role_definition}")
sleep 10s
assign_role_to_sp ${app_id} ${role_name}

}



create_ad_resources() {
  CREDENTIALS="$(az ad sp create-for-rbac -n "ces-freemium-app" --skip-assignment -o json)"
  echo "${CREDENTIALS}"
  
}

preflight() {
  confirm_jq_installed
  confirm_az_login
  extension_auto_install
  get_subscriptions
}



main(){

preflight
CREDENTIALS=$(create_ad_resources)
app_id=$(echo "${CREDENTIALS}" | jq -j '.appId')
tenant_id=$(echo "${CREDENTIALS}" | jq -j '.tenant')
secret=$(echo "${CREDENTIALS}" | jq -j '.password')
create_assign_role
print_outputs_headline
print_outputs


}
main
