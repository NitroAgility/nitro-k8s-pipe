#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2020 Nitro Agility Srl
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

dry_run=0
verbose=0
os=ubuntu
infrastructure=aws
source=$(pwd)
install=0
task=deploy

function usage()
{
    cat <<END
     __ _  __  ____  ____   __       __ _  ____  ____      ____  __  ____  ____ 
    (  ( \(  )(_  _)(  _ \ /  \  ___(  / )/ _  \/ ___) ___(  _ \(  )(  _ \(  __)
    /    / )(   )(   )   /(  O )(___))  ( ) _  (\___ \(___)) __/ )(  ) __/ ) _) 
    \_)__)(__) (__) (__\_) \__/     (__\_)\____/(____/    (__)  (__)(__)  (____)

                                                  Copyright © 2020 Nitro Agility

    Usage:  $0 -nv -s source_dir -o os
                -n, --dry-run       dry run, don't make any changes
                -v, --verbose       verbose output
                -s, --source        source directory (defaults to $source)
                -t, --task          task to be executed (defaults to $task)
                -i, --install       install required tools
                --os                override operating system (defaults to $os)
                --infrastructure    override infrastructure (defaults to $infrastructure)
                -h, --help          display this message

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

function task_os_tools_install(){
    log_trace "preparing for installation"
    apt update
    log_trace "installing curl"
    apt-get install -y curl
    log_trace "installing unzip"
    apt-get install -y unzip
}

function task_k8s_tools_install(){
    log_trace "installing kubectl"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin
}

function task_helm_install(){
    log_trace "installing helm"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh 
}

function task_aws_cli_install(){
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

function task_aws_cli_configure(){
    log_trace "configuring the aws cli"
    aws configure set aws_access_key_id $PIPE_AWS_ACCESS_KEY
    aws configure set aws_secret_access_key $PIPE_AWS_SECRET_ACCESS_KEY
}

function task_aws_eks_configure(){
    log_trace "configuring kubeclt to connect to the aws eks cluster"
    aws eks --region eu-west-2 update-kubeconfig --name jobs4k-eks-EvydAE8P
}

function task_helm_deploy(){
    log_trace "deploying chart $chart"
    helm upgrade --install jobs4k ./chart/"$chart"/ --set environment=dev -n dev
}

function process_args() {
    # parse options
    SHORT=s:t:nvh:
    LONG=dry-run,verbose,help,install,source:,task:,os:,infrastructure:
    OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    if [ $? != 0 ] ; then log_error "Failed to parse options" >&2 ; exit 1 ; fi
    eval set -- "$OPTS"
    while true; do
        case "$1" in
            -n | --dry-run) dry_run=1; shift ;;
            -v | --verbose) verbose=1; shift ;;
            -s | --source) source="$2"; shift 2 ;;
            -t | --task) task="$2"; shift 2 ;;
            -i | --install) install=1; shift ;;
            --os) os="$2"; shift 2 ;;
            --infrastructure) infrastructure="$2"; shift 2 ;;
            -h | --help) usage ; exit 1; shift ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done
}

function run_tasks(){
    if [[ install -eq 1 ]]; then
        log_trace "insalling required tools"
        task_os_tools_install
        task_k8s_tools_install
        task_helm_install
    fi
    case $infrastructure in
        aws)
            log_trace "configuring aws infrastructure"
            task_aws_cli_install
            task_aws_cli_configure
            task_aws_eks_configure ;;
        *) log_error "infrastructure $infrastructure is not supported" ; exit 1 ;;
    esac
    task_helm_deploy
}

# process the input arguments
process_args "$@"
# run the tasks
#run_tasks