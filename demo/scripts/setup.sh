#! /usr/bin/env bash

oc new-project dev
oc new-project test
oc new-project prod

oc new-app --template=jenkins-ephemeral --name=jenkins -n dev

oc adm policy add-role-to-user edit system:serviceaccount:dev:jenkins -n test
oc adm policy add-role-to-user edit system:serviceaccount:dev:jenkins -n prod

oc create secret generic repository-credentials --from-file=ssh-privatekey=$HOME/.ssh/id_rsa --type=kubernetes.io/ssh-auth -n dev
oc label secret repository-credentials credential.sync.jenkins.openshift.io=true -n dev
oc annotate secret repository-credentials 'build.openshift.io/source-secret-match-uri-1=ssh://github.com/*' -n dev

oc new-build git@github.com/redhatcsargentina/openshift-cicd-pipelines.git --name=openshift-hello-world --strategy=pipeline -e APP_NAME=openshift-hello-world -n dev
