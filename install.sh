#!/bin/bash

# setup.sh
#
# This is just a little script to:
# - create home for pathr
# - install microk8s
# - install bunch of tools, plugins, etc

set -ue

USERNAME="pathr"

SNAP_CHANNEL_VERSION="1.28"
_divider="--------------------------------------------------------------------------------"
_prompt=">>>"
_indent="   "

header() {
    cat 1>&2 <<EOF
                      _____      _   _          
                     |  __ \    | | | |         
                     | |__) |_ _| |_| |__  _ __ 
                     |  ___/ _' | __| '_ \| '__|
                     | |  | (_| | |_| | | | |   
                     |_|   \__,_|\__|_| |_|_|   
                            
                            
                    P A T H R
                    Installer


$_divider
Website: https://pathr.ai
$_divider

EOF
}

usage() {
    cat 1>&2 <<EOF
pathr-install
The installer for Pathr (https://pathr.ai)

USAGE:
    pathr-install [FLAGS] [OPTIONS]

FLAGS:
    -y                      Disable confirmation prompt.
    -h, --help              Prints help information
EOF
}

main() {

    header

    local prompt=yes
    # Parse command-line options
    while getopts "hyu:" opt; do
        case ${opt} in
            h)
                usage
                exit 0
                ;;
            y)
                prompt=no
                ;;
            u)
                USERNAME=$OPTARG
                ;;
            \? )
                echo "Invalid option: $OPTARG" 1>&2
                show_usage
                exit 1
                ;;
            :)
                echo "Invalid option: $OPTARG requires an argument" 1>&2
                show_usage
                exit 1
                ;;
        esac
    done


    if [ "$prompt" = "yes" ]; then
        echo "$_prompt Ready to proceed? (y/n)"
        echo ""

        while true; do
            read -rp "$_prompt " _choice </dev/tty
            case $_choice in
                n)
                    err "exiting"
                    ;;
                y)
                    break
                    ;;
                *)
                    echo "Please enter y or n."
                    ;;
            esac
        done

        echo ""
        echo "$_divider"
        echo ""
    fi

    verify

    create_user
    install
    setup
}

user_can_sudo() {
  # Check if sudo is installed
  need_cmd sudo

  # The following command has 3 parts:
  #
  # 1. Run `sudo` with `-v`. Does the following:
  #    • with privilege: asks for a password immediately.
  #    • without privilege: exits with error code 1 and prints the message:
  #      Sorry, user <username> may not run sudo on <hostname>
  #
  # 2. Pass `-n` to `sudo` to tell it to not ask for a password. If the
  #    password is not required, the command will finish with exit code 0.
  #    If one is required, sudo will exit with error code 1 and print the
  #    message:
  #    sudo: a password is required
  #
  # 3. Check for the words "may not run sudo" in the output to really tell
  #    whether the user has privileges or not. For that we have to make sure
  #    to run `sudo` in the default locale (with `LANG=`) so that the message
  #    stays consistent regardless of the user's locale.
  #
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

verify() {
  if ! user_can_sudo; then
    err "need sudo"
  fi
}

setup() {
    say 'do dome setup'
}

create_user() {
    USERHOME="/home/${USERNAME}"
    say "creating ${USERNAME} user with home in ${USERHOME}"
    sudo adduser ${USERNAME} --home ${USERHOME} --system --disabled-password --shell /usr/bin/zsh
    sudo passwd --delete ${USERNAME}
    sudo usermod -a -G sudo ${USERNAME}

    sudo mkdir -p ${USERHOME}/.kube
    sudo chown -R ${USERNAME} ${USERHOME}
}

install() {
    say "installation start"
    install_zsh
    install_microk8s
    install_helm
    install_kubectl
    # install_krew
    # install_krew_plugins
    # install_other
    # install_flux
    say "installation end"
}

install_other() {
    say "installing other tools"
    sudo apt update && sudo apt install -y fzf dos2unix speedtest-cli tree apt-offline jq wget ffmpeg apt-transport-https ca-certificates curl gnupg-agent software-properties-common zip unzip python3-pip mlocate
}

install_flux() {
    say "installation flux"
    curl -s https://fluxcd.io/install.sh | sudo bash
}

install_zsh() {
    say "installing zsh"
    need_cmd apt
    sudo apt install -y zsh
    zsh --version

    # download oh-myl-zsh installation script
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/i.sh && chmod +x /tmp/i.sh
    sudo -u ${USERNAME} sh -c 'RUNZSH=no /tmp/i.sh'

    sudo sed -i 's/^plugins=(.*)/plugins=(git kubectl)/' ${USERHOME}/.zshrc 
}

install_helm() {
    say "installing helm"
    sudo snap install helm --classic
}

install_kubectl() {
    say "installing kubectl"
    need_cmd snap
    sudo snap install kubectl --classic
}

install_krew() {
    # install kubectl-ns

    cd /tmp
    OS="$(uname | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
    KREW="krew-${OS}_${ARCH}"
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
    tar zxvf "${KREW}.tar.gz"
    mv /tmp/krew-${OS}_${ARCH} /tmp/krew

    # executed as pathr user
    sudo -u ${USERNAME} zsh -c '/tmp/krew install krew'
    sudo -u ${USERNAME} zsh -c 'echo "export PATH=\"${KREW_ROOT:-$HOME/.krew}/bin:$PATH\"" >> ${HOME}/.zshrc'

}

install_krew_plugins() {
    # https://github.com/ahmetb/kubectx
    sudo -u ${USERNAME} zsh -c 'source ~/.zshrc; kubectl krew install ctx'
    sudo -u ${USERNAME} zsh -c 'source ~/.zshrc; kubectl krew install ns'
}

install_microk8s() {
    say "installing microk8s"
    need_cmd snap
    sudo snap install microk8s --classic --channel=${SNAP_CHANNEL_VERSION}

    # wait untill ready
    sudo microk8s status --wait-ready

    # prepare for pathr user
    sudo usermod -a -G microk8s ${USERNAME}
    sudo microk8s config > /tmp/kube_config
    sudo mv /tmp/kube_config ${USERHOME}/.kube/config
    sudo chown -R ${USERNAME} ${USERHOME}/.kube
    sudo chmod 600 ${USERHOME}/.kube/config

    # enabled addons
    sudo microk8s enable dns
    sudo microk8s enable hostpath-storage
}

say() {
    printf 'pathr-install: %s\n' "$1"
}


err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

main "$@" || exit 1