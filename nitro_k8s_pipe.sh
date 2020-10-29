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

# Core variables
dry_run=0
verbose=0
source=$(pwd)
install=0
push_container=0
deploy=0
build_number=0
docker_file=
docker_build_args=
docker_registry=
docker_registry_name=
os=ubuntu
infrastructure=aws
k8s_cluster=
helm_chart=
helm_release_name=
helm_release_namespace=
helm_install=1

# AWS variables
aws_key=$PIPE_AWS_ACCESS_KEY
aws_secret=$PIPE_AWS_SECRET_ACCESS_KEY

function usage()
{
    cat <<END
     __ _  __  ____  ____   __       __ _  ____  ____      ____  __  ____  ____ 
    (  ( \(  )(_  _)(  _ \ /  \  ___(  / )/ _  \/ ___) ___(  _ \(  )(  _ \(  __)
    /    / )(   )(   )   /(  O )(___))  ( ) _  (\___ \(___)) __/ )(  ) __/ ) _) 
    \_)__)(__) (__) (__\_) \__/     (__\_)\____/(____/    (__)  (__)(__)  (____)

                                                  Copyright © 2020 Nitro Agility

    Usage:  $0 -nv --source source_dir --chart my_chart
                -n, --dry-run           dry run, don't make any changes
                -v, --verbose           verbose output
                -s, --source            source directory (defaults to $source)
                -i, --install-tools     install required tools
                --push-container        push the container
                --deploy                deploy the container
                --os                    override operating system (defaults to $os)
                --infrastructure        override infrastructure (defaults to $infrastructure)
                --build-number          build number
                --docker-file           docker file
                --docker-build-args     docker build arguments
                --docker-registry       docker registry url
                --docker-registry-name  docker registry name
                --cluster               kubernetes cluster name
                --chart                 helm chart name [required option]
                --release               helm release name (defaults to the chart name)
                --namespace             helm namespace
                --uninstall             uninstall the helm chart
                --pre-deploy            script to be executed before of the deploy [base64]
                -h, --help              display this message
            there are custom options for each infrastructure type.
                aws:
                    --aws-key               aws access key id [required option]
                    --aws-secret            aws secret access key [required option]
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
    aws configure set aws_access_key_id $aws_key
    aws configure set aws_secret_access_key $aws_secret
}

function task_aws_ecr_configure(){
    log_trace "configuring to connect to the aws docker registry"
    aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $docker_registry
}

function task_aws_eks_configure(){
    log_trace "configuring kubeclt to connect to the aws eks cluster"
    aws eks --region eu-west-2 update-kubeconfig --name $k8s_cluster
}

function task_docker_deploy(){
    if [-z "$docker_build_args" ]; then
        docker_file = "./Dockerfile"
    fi
    log_trace "Dockerfile $docker_file"
    if [[ $docker_build_args ]]; then
        eval "docker build -t $docker_registry_name:latest . $docker_build_args -f $docker_file"
    else
        eval "docker build -t $docker_registry_name:latest . -f $docker_file"
    fi
    docker tag $docker_registry_name:latest $docker_registry/$docker_registry_name:latest
    docker push $docker_registry/$docker_registry_name:latest
    docker tag $docker_registry_name:latest $docker_registry/$docker_registry_name:$build_number
    docker push $docker_registry/$docker_registry_name:$build_number
}

function task_helm_deploy(){
    if [[ $helm_install -eq 1 ]]; then
        log_trace "installing chart $helm_chart"
        if [[ $helm_release_namespace ]]; then
            helm upgrade --install $helm_release_name "$source/chart/$helm_chart" --set app.tag=$build_number -n $helm_release_namespace
        else
            helm upgrade --install $helm_release_name "$source/chart/$helm_chart" --set app.tag=$build_number
        fi
    else
        log_trace "uninstalling chart $helm_chart"
        if [[ $helm_release_namespace ]]; then
            helm uninstall $helm_release_name -n $helm_release_namespace
        else
            helm uninstall $helm_release_name
        fi
    fi
}

function process_args() {
    # parse options
    SHORT=nvs:io:h
    LONG=dry-run,verbose,help,install-tools,push-container,deploy,source:,build-number:,docker-build-args:,docker-file:,docker-registry:,docker-registry-name:,os:,infrastructure:,cluster:,chart:,release:,namespace:,uninstall,pre-deploy:,aws-key:,aws-secret:
    OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    if [ $? != 0 ] ; then log_error "Failed to parse options" >&2 ; exit 1 ; fi
    eval set -- "$OPTS"
    while true; do
        case "$1" in
            -n | --dry-run) dry_run=1; shift ;;
            -v | --verbose) verbose=1; shift ;;
            -s | --source) source=${2%/}; shift 2 ;;
            -i | --install-tools) install=1; shift ;;
            --push-container) push_container=1; shift ;;
            --deploy) deploy=1; shift ;;
            --build-number) build_number="$2"; shift 2 ;;
            --docker-file) docker_file="$2"; shift 2 ;
            --docker-build-args) docker_build_args=$(echo "$2" | base64 --decode); shift 2 ;;
            --docker-registry) docker_registry="$2"; shift 2 ;;
            --docker-registry-name) docker_registry_name="$2"; shift 2 ;;
            --os) os="$2"; shift 2 ;;
            --infrastructure) infrastructure="$2"; shift 2 ;;
            --cluster) k8s_cluster="$2"; shift 2 ;;
            --chart) helm_chart="$2"; shift 2 ;;
            --release) helm_release_name="$2"; shift 2 ;;
            --namespace) helm_release_namespace="$2"; shift 2 ;;
            --uninstall) helm_install=0; shift ;;
            --pre-deploy) pre_deploy=$(echo "$2" | base64 --decode); shift 2 ;;
            --aws-key) aws_key="$2"; shift 2 ;;
            --aws-secret) aws_secret="$2"; shift 2 ;;
            -h | --help) usage ; exit 1; shift ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done
    if [[ deploy -eq 1 ]]; then
        [[ $helm_chart ]] ||  { log_error "helm chart is a required" >&2; exit 1; }
        [[ $helm_release_name ]] || helm_release_name=$helm_chart
    fi
}

function run_tasks(){
    if [[ install -eq 1 ]]; then
        log_trace "insalling required tools"
        task_os_tools_install
        task_k8s_tools_install
        task_helm_install
        case $infrastructure in
            aws)
                log_trace "configuring aws infrastructure"
                task_aws_cli_install
                task_aws_cli_configure
                task_aws_ecr_configure
                task_aws_eks_configure ;;
            *) log_error "infrastructure $infrastructure is not supported" >&2 ; exit 1 ;;
        esac
    fi
    if [[ push_container -eq 1 ]]; then
        log_trace "pushing the docker registry"
        task_docker_deploy
    fi
    if [[ deploy -eq 1 ]]; then
        log_trace "pushing to helm"
        [ ! $pre_deploy ] || eval $pre_deploy
        task_helm_deploy
    fi
}

# process the input arguments
process_args "$@"
# run the tasks
run_tasks