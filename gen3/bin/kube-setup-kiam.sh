#!/bin/bash
#
# Setup aws iam management with kiam

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

g3kubectl apply -f "${GEN3_HOME}/kube/services/kiam/kiam-server-rbac.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/kiam/kiam-server-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/kiam/kiam-server-daemonset.yaml"
