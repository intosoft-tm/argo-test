#!/bin/bash

NAMESPACE=argocd

echo "== Step 1: Detaching resources from Argo CD management =="

# Loop over all Argo CD Applications
for app in $(microk8s kubectl get applications.argoproj.io -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
  label="argocd.argoproj.io/instance=${app}"
  echo "Removing label '$label' from resources tracked by Application '$app'..."

  # Find all resources with that label in all namespaces
  resources=$(microk8s kubectl get all --all-namespaces -l "$label" -o name)

  if [[ -z "$resources" ]]; then
    echo "No resources found with label $label"
  else
    # Remove the Argo CD label from each resource so Argo CD stops tracking them
    for res in $resources; do
      echo "  Removing label from $res"
      microk8s kubectl label --overwrite "$res" "$label"- || echo "Failed to remove label from $res"
    done
  fi
done

# Remove finalizers from all Argo CD Applications to avoid cascade deletion
echo "Removing finalizers from Argo CD Applications..."
for app in $(microk8s kubectl get applications.argoproj.io -n $NAMESPACE -o name); do
  microk8s kubectl patch "$app" -n $NAMESPACE -p '{"metadata":{"finalizers":[]}}' --type=merge
done

echo "Detachment complete."