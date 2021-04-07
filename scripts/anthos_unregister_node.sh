#!/bin/bash
source ~/variables.sh
#tojson <array>
function tojson {
    array=("$@")
    cnt=${#array[@]}
    for ((i=0;i<cnt;i++)); do
      array[i]="{\"address\":\"${array[i]}\"}"
    done
    joined=$(join , "${array[@]}")
    echo "[$joined]" 
}

#tojson <delimiter> <array>
function join { 
        local IFS="$1"; shift; echo "$*"; 
}

#get_node_pool <namespace> <anthos cluster name>
function get_node_pool {
        node_pools=$(kubectl --request-timeout=5s -n "$1" get nodepools.baremetal.cluster.gke.io | grep -vi "^name\|^$2" | cut -d' ' -f1)
        amount=$(echo "$node_pools" | wc -l)
        if [ "$amount" !=  "1" ]
        then
                echo "unable to retrieve nodepool name: none or multiple found"
                exit 1
        fi
        echo "$node_pools"
}


# check <namespace> <node-pool name>
function wait {
    NEXT_WAIT_TIME=0
    ITERATION=60
    until [ $NEXT_WAIT_TIME -eq $ITERATION ] || check "$1" "$2"; do
        sleep 10
        ((NEXT_WAIT_TIME++))
    done
    if [ $NEXT_WAIT_TIME -lt $ITERATION ]
    then
        return 0
    fi
    return 1
}

# check <namespace> <node-pool name>
function check {
    expected="ReconciliationCompleted"
    status=$(kubectl --request-timeout=5s -n "$1" describe nodepools.baremetal.cluster.gke.io "$2" | grep -oP "(?<=Reason:).*"| sed 's/ *//g')
    if [ "$status" == "$expected" ] || ! kubectl cluster-info --request-timeout=5s
    then
        echo "stop waiting: $status"
        return 0
    fi
    echo "still waiting: $status"
    return 1
}


# wait_node_removal <to_remove_ip> 
function wait_node_removal {
    echo "Starting wait_node_removal"
    NEXT_WAIT_TIME=0
    ITERATION=60
    until [ $NEXT_WAIT_TIME -eq $ITERATION ] ||  check_removal "$1"; do
        echo "removal of node $1 not yet complete... sleeping 30 seconds"
        sleep 30
        ((NEXT_WAIT_TIME++))
    done
    if [ $NEXT_WAIT_TIME -lt $ITERATION ]
    then
        return 0
    fi
    return 1

}

# check_removal <to_remove_ip>
function check_removal {
    expected="0"
    status=$(kubectl --request-timeout=5s get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | grep -ic "$1")
    if [ "$status" == "$expected" ] || ! kubectl cluster-info --request-timeout=5s
    then
        echo "stop waiting for removal of node $1: $status"
        return 0
    fi
    echo "still waiting for removal of node $1: $status"
    return 1
}

echo "Checking if kubectl is installed"
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found. Node was not part of Anthos cluster"
    exit 0
fi

echo "Checking if cluster is still online"
if ! kubectl cluster-info --request-timeout=5s
then 
    echo "cluster was not reachable (already destroyed?). Exiting"
    exit 0
fi

to_remove_ip="$1"
namespace="cluster-$ANTHOS_CLUSTER_NAME"
echo "Getting Worker nodepool"
nodepool=$(get_node_pool "$namespace" "$ANTHOS_CLUSTER_NAME")

echo "Removing node from cluster"
until ! kubectl cluster-info --request-timeout=5s || kubectl --request-timeout=5s -n "$namespace" get nodepools.baremetal.cluster.gke.io "$nodepool" -o yaml | sed  "/- address: $to_remove_ip/d" | kubectl --request-timeout=5s apply -f - && wait "$namespace" "$nodepool" && ! $(kubectl --request-timeout=5s -n "$namespace" get nodepools.baremetal.cluster.gke.io "$nodepool" -o yaml | grep -q -- "- address: $to_remove_ip")
do
    sleep 20
done

echo "Starting wait"
wait "$namespace" "$nodepool" && wait_node_removal "$to_remove_ip"