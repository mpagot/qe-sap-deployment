#!/bin/sh

function ErrChk() {
  if [[ $? -ne 0 ]] ; then
    echo "Command failed"
    exit 1
  fi
}

function usage {
  echo "Usage:

  $0 -k <SSH key file>

Options
  k - SSH key: private SSH key that will be used to access the VM
  v - verbose mode
  h - print this help

Example:
  $0 -k ~/.ssh/id_rsa_cloud
" >&2
}

while getopts ":vhk:" options
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

source variables.sh
ErrChk

TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
#AnsFlgs="${AnsFlgs} -vvvv"
AnsPlybkPath="./ansible/playbooks"

echo "--QE_SAP DEPLOY--"

### TERRAFORM BIT ###
TF_LOG_PATH=terraform.init.log TF_LOG=INFO terraform -chdir="${TerraformPath}" init
ErrChk
TF_LOG_PATH=terraform.plan.log TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip
ErrChk
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip
ErrChk

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
ErrChk

ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/iscsi-server-configuration.yaml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-stroage.yml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml
ErrChk
