#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2020 Nitro Agility
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

verbose=0
os=linux
infrastructure=aws
operation=

function usage()
{
    cat <<END
     __ _  __  ____  ____   __       __ _  ____  ____      ____  __  ____  ____ 
    (  ( \(  )(_  _)(  _ \ /  \  ___(  / )/ _  \/ ___) ___(  _ \(  )(  _ \(  __)
    /    / )(   )(   )   /(  O )(___))  ( ) _  (\___ \(___)) __/ )(  ) __/ ) _) 
    \_)__)(__) (__) (__\_) \__/     (__\_)\____/(____/    (__)  (__)(__)  (____)

    Usage:  $0 -nv -s source_dir -o os
                -n     dry run, don't make any changes
                -s     source directory. Defaults to $thisdir
                -i     override target infrastructure (defaults to $infrastructure)
                -o     override operating system (defaults to $os)
                -v     verbose output
                -h     display this message

END
}

function log_error(){
    printf '\e[31mERROR: %s\e[0m\n' "$1" 
}

function log_warning(){
    printf '\e[93m%s\e[0m\n' "$1" 
}

function log_info(){
    printf '%s\n' "$1" 
}

function log_trace(){
    if [[ $verbose -eq 1 ]] ; then
        printf '\e[96mTRACE: %s\e[0m\n' "$1" 
    fi
}

function install_os_tools(){
    log_trace "preparing for installation"
    apt update
    log_trace "installing curl"
    apt-get install -y curl
    log_trace "installing unzip"
    apt-get install -y unzip
}

function install_k8s(){
    log_trace "installing kubectl"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin
}

function install_helm(){
    log_trace "installing helm"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh 
}

function install_awscli(){
    log_trace "installing awscli v2"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install

    log_trace "installing aws-iam-authenticator"
    curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator
    chmod +x ./aws-iam-authenticator
    mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$PATH:$HOME/bin
    echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
}

function configure_aws(){
    log_trace "installing awscli v2"
    aws configure set aws_access_key_id $PIPE_AWS_ACCESS_KEY
    aws configure set aws_secret_access_key $PIPE_AWS_SECRET_ACCESS_KEY
}

function configure_aws_eks(){
    log_trace "installing awscli v2"
    aws eks --region eu-west-2 update-kubeconfig --name jobs4k-eks-EvydAE8P
}

function helm_deploy(){
    log_trace "deploying chart $chart"
    helm upgrade --install jobs4k ./chart/"$chart"/ --set environment=dev -n dev
}

function process_args() {
    while getopts ":s:r:nvh" flag; do
        case $flag in
            s) echo "source ${OPTARG%/}" ;;
            r) operation="${OPTARG}" ;;
            n) echo "dry run${OPTARG}" ;;
            v) verbose=1;;
            h) usage ; exit 1 ;;
        esac
    done
}

process_args "$@"
install_os_tools