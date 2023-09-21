#!/bin/sh

help() {
  echo "usage: ./bootstrap.sh -p <customer_name> -c <cluster_ctx>

Ex. ./bootstrap.sh -p matt -c microk8s
"
}

bootstrap() {
  flux bootstrap github \
    --owner=${OWNER} \
    --repository=${REPO} \
    --path=${CLUSTER_PATH} \
    --branch=main \
    --ssh-key-algorithm ed25519 \
    --private \
    --components-extra=image-reflector-controller,image-automation-controller
}

# ###########################################
OWNER="pathr"
REPO="gitops-k8s-edge"
# ###########################################

while getopts ":c:b:p:h:" opt; do
  case "$opt" in
    h)
      help
      exit 0
      ;;
    p) 
      CUSTOMER=$OPTARG
      ;;
    c) 
      CLUSTER_CTX=$OPTARG
      ;;
    \? ) 
      help
      exit 0s
      ;;
  esac
done

CLUSTER_PATH="clusters/${CUSTOMER}/${CLUSTER_CTX}"

echo "Bootstrapping ${CLUSTER_CTX} with flux2 (https://fluxcd.io/)"
while true; do
    echo ""
    read -p "Do you wish to continue with bootstrap [y/n]?" yn
    case $yn in
        [Yy]* ) bootstrap; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
