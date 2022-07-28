#!/bin/sh

set -e

function usage {
  echo "Usage:

  $0 -k <SSH key file>

Options
  k - SSH key: private SSH key that will be used to access the VM
  s - skip the Ansible configuration (all out of the registration)
  v - verbose mode
  h - print this help

Example:
  $0 -k ~/.ssh/id_rsa_cloud
" >&2
}

while getopts ":vhsk:" options
  do
    case "${options}"
      in
        v)
          verbose=1
          ;;
        h)
           usage
           exit 0
           ;;
        k)
          ssh_key="${OPTARG}"
          ;;
        s)
          skip=1
          ;;
        \?)
          echo "Invalid option: -${OPTARG}" >&2
          exit 1
          ;;
        :)
          echo "Option -${OPTARG} requires an argument." >&2
          exit 1
          ;;
        *)
          usage
          exit 1
          ;;
    esac
done

if [ -z "$1" ]
  then
    usage
    exit 0
fi

if [ -z "${ssh_key}" ]
  then
    echo "ssh key must be set"
    error=1
fi

if [ ! -f "${ssh_key}" ]
  then
    echo "provided ssh key file couldn't be found"
    error=1
fi

if [ -n "${error}" ]
  then
    exit 1
fi

. ./variables.sh

TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
#AnsFlgs="${AnsFlgs} -vvvv"
AnsPlybkPath="./ansible/playbooks"

echo "--QE_SAP_DEPLOYMENT--"

### TERRAFORM BIT ###
TF_LOG_PATH=terraform.init.log TF_LOG=INFO terraform -chdir="${TerraformPath}" init
TF_LOG_PATH=terraform.plan.log TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip

### ANSIBLE BIT ###
if [ -z ${SSH_AGENT_PID+x} ]
then
  echo "No SSH_AGENT_PID"
  eval $(ssh-agent)
else
  if ps -p $SSH_AGENT_PID > /dev/null
  then
    echo "ssh-agent is already running at ${SSH_AGENT_PID}"
  else
    echo "ssh-agent is NOT running at ${SSH_AGENT_PID}"
    eval $(ssh-agent)
  fi
fi

ssh-add -v "${ssh_key}"

### ANSIBLE BIT ###
# Accept new ssh keys for ansible-controlled hosts
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"

# Run registration
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"

# Option to quit if we don't want to run all plays
if [ $skip -eq 1 ] ; then
  echo "Skipping build tasks"
  exit 0
fi

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/cluster_sbd_prep.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-stroage.yml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml
