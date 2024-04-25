#!/bin/bash

kubectl create namespace httpd-namespace-nautilus 
kubectl create -f http.yaml
kubectl get pods