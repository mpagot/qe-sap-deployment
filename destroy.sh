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

echo "--QE_SAP DESTROY--"


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

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/deregister.yaml
#ErrChk

### TERRAFORM BIT ###
terraform -chdir="${TerraformPath}" destroy -auto-approve
ErrChk