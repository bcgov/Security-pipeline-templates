#!/bin/bash
set -o errexit
set -o pipefail

export PATH=$PATH:${PWD}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export cyan=$(tput setaf 6)
export green=$(tput setaf 2)
export warn=$(tput setaf 3)
export bold=$(tput bold)
export normal=$(tput sgr0)

function apply(){
    secrets
    if [ -z "${CONTEXT}" ]; then
        kubectl apply -k overlays/apply || prune
    else
        kubectl config use-context ${CONTEXT}
        kubectl apply -k overlays/apply || prune
    fi
    echo "${green}apply completed successfully...${normal}"
}

function secrets(){
    pip install -r ${DIR}/overlays/secrets/requirements.txt --exists-action i --quiet
    python ${DIR}/overlays/secrets/main.py

    if [ -z "${CONTEXT}" ]; then
        kubectl apply -k overlays/secrets
    else
        kubectl config use-context ${CONTEXT}
        kubectl apply -k overlays/secrets
    fi

    rm -rf overlays/secrets/kustomization.yaml
    rm -rf overlays/secrets/.secrets
    echo "${green}Secrets configured successfully...${normal}"
}

function prune(){
    setup
    kubectl delete pipelinerun $(kubectl get pipelinerun | awk '{print $1}') 2> /dev/null || echo "${green}Pruning completed successfully...${normal}"
}

function display_help() {
    SHORT_SHA="$(git rev-parse --short HEAD)"
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    echo ""
    echo "${cyan}Tekton Kustomize CLI${normal}"
    echo "${cyan}Version: ${BRANCH}-${SHORT_SHA}${normal}"
    echo ""
    echo "Usage: tekton.sh [option...]" >&2
    echo
    echo "   ${bold}-a, --apply${normal}         Apply secrets, pipelines, tasks, and triggers. "
    echo "   ${bold}-p, --prune${normal}         Delete all ${bold}Completed${normal}, $(tput bold)Errored${normal} or $(tput bold)DeadLineExceeded${normal} pod runs. "
    echo "   ${bold}-h, --help${normal}          Display argument options. "
    echo
    exit 1
}

while :
do
    case "$1" in
      -h | --help)
          display_help
          exit 0
          ;;
      -a | --apply)
          apply
          shift 2
          ;;
      -p | --prune)
          prune
          shift 2
          ;;

      --) # End of all options
          shift
          break
          ;;
      -*)
          echo "Error: Unknown option: $1" >&2
          ## or call function display_help
          exit 1
          ;;
      *)  # No more options
          break
          ;;
    esac
done

case "$1" in
  *)
     display_help

     exit 1
     ;;
esac
