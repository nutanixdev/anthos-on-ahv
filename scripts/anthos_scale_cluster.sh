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

# join <delimiter> <array>
function join { 
        local IFS="$1"; shift; echo "$*"; 
}

# get_node_pool <namespace> <anthos cluster name>
function get_node_pool {
        node_pools=$(kubectl -n "$1" get nodepools.baremetal.cluster.gke.io | grep -vi "^name\|^$2" | cut -d' ' -f1)
        amount=$(echo "$node_pools" | wc -l)
        if [ "$amount" !=  "1" ]
        then
                echo "unable to retrieve nodepool name: none or multiple found"
                exit 1
        fi
        echo "$node_pools"
}


# wait check_add <namespace> <node-pool name> | wait check_removal <expected worker node count>
function wait {
    NEXT_WAIT_TIME=0
    ITERATION=60
    until [ $NEXT_WAIT_TIME -eq $ITERATION ] || $1 "$2" "$3"; do
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
function check_add {
    expected="ReconciliationCompleted"
    status=$(kubectl -n "$1" describe nodepools.baremetal.cluster.gke.io "$2" | grep -oP "(?<=Reason:).*"| sed 's/ *//g')
    if [ "$status" == "$expected" ]
    then
        echo "stop waiting: $status"
        return 0
    fi
    echo "still waiting: $status"
    return 1
}

# check_removal <expected worker node count>
function check_removal {
    expected="$1"
    status=$(kubectl get node --selector='!node-role.kubernetes.io/master' | grep -vi "^name" | wc -l)
    if [ "$status" == "$expected" ] || ! kubectl cluster-info --request-timeout=5s
    then
        echo "stop waiting for removal: $status"
        return 0
    fi
    echo "still waiting for removal: $status"
    return 1
}

namespace="cluster-$ANTHOS_CLUSTER_NAME"
nodepool=$(get_node_pool "$namespace" "$ANTHOS_CLUSTER_NAME")
# Get current node IPs
echo "Fetch current worker node IPs"
current_node_ips=($(kubectl -n $namespace describe nodepools.baremetal.cluster.gke.io $nodepool | grep  -oP "(?<=Address:).*"))
# Get the current amount of nodes
current_node_length="${#current_node_ips[@]}"
echo "Current node IPS: $current_node_ips"
echo "ANTHOS_WORKERNODES_ADDRESSES: $ANTHOS_WORKERNODES_ADDRESSES"
# Read new node_ips from env
IFS=',' read -r -a new_nodes <<< "$ANTHOS_WORKERNODES_ADDRESSES"
new_node_length="${#new_nodes[@]}"

# Check if the amount of nodes are equal
if [ "$current_node_length" -eq  "$new_node_length" ]
then
        echo "not performing scale-up or down"
        exit 0
fi
# Make sure we don't scale down to zero workers
if [ "$new_node_length" -eq  "0" ]
then
        echo "cannot scale to 0 nodes"
        exit 1
fi

jsonstring=$(tojson "${new_nodes[@]}")
echo "Patching nodepool to start scaling"
kubectl patch -n "$namespace" nodepools.baremetal.cluster.gke.io "$nodepool" -p "{\"spec\":{\"nodes\": $jsonstring }}" --type=merge
sleep 20

# Check if this is a scale in task
if [ "$new_node_length" -lt  "$current_node_length" ]
then
        wait "check_removal" "$new_node_length"
        exit 0
fi

# Check if this is a scale out task
if [ "$new_node_length" -gt  "$current_node_length" ]
then
        wait "check_add" "$namespace" "$nodepool"
        exit 0
fi
