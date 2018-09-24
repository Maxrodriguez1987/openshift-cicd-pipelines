#! /usr/bin/env bash

# Sets the MiniShift profile for the non-prod cluster
minishift profile set non-prod

# Starts the non-prod cluster
minishift start

# Logs in as admin to create projects
oc login "https://$(minishift ip):8443" -u admin -p admin

# Creates projects for development (n areas, n projects)
oc new-project core-dev
oc new-project apis-dev

# Creates the test projects (n areas, n projects)
oc new-project core-test
oc new-project apis-test

# Creates the prod (management) projects (n areas, n projects)
oc new-project core-prod-management
oc new-project apis-prod-management

# Creates the development templates in the development projects
oc create -f ./environments/dev/dev-pipelines-template.yaml -n core-dev
oc create -f ./environments/dev/branch-pipeline-template.yaml -n core-dev
oc create -f ./environments/dev/dev-pipelines-template.yaml -n apis-dev
oc create -f ./environments/dev/branch-pipeline-template.yaml -n apis-dev

# Creates the test template in the test projects
oc create -f ./environments/test/test-pipeline-template.yaml -n core-test
oc create -f ./environments/test/test-pipeline-template.yaml -n apis-test

# Creates the prod template in the prod projects
oc create -f ./environments/prod/prod-pipeline-template.yaml -n core-prod-management
oc create -f ./environments/prod/prod-pipeline-template.yaml -n apis-prod-management

# Gogs

oc new-project gogs

oc new-app -f http://bit.ly/openshift-gogs-persistent-template --param=HOSTNAME="gogs-gogs.$(minishift ip).nip.io" -n gogs

# Jenkins

# Creates the Jenkins project
oc new-project jenkins

# Deploys Jenkins
oc new-app jenkins-persistent -n jenkins

# Sets Jenkins service account permissions
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n core-dev
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n apis-dev
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n core-test
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n apis-test
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n core-prod-management
oc adm policy add-role-to-user edit system:serviceaccount:jenkins:jenkins -n apis-prod-management

# Creates a new cluster role for reading groups in the cluster
oc create -f ./configuration/roles/group-reader.yaml

# Allows jenkins service account to read groups from cluster
oc adm policy add-cluster-role-to-user group-reader system:serviceaccount:jenkins:jenkins

# Avoids a Jenkins instance in every project a pipeline is created
minishift openshift config set --patch '{"jenkinsPipelineConfig":{"autoProvisionEnabled":false}}'

# Creates new groups
oc adm groups new developers
oc adm groups new testers
oc adm groups new administrators
oc adm groups new test-approvers
oc adm groups new prod-approvers

# Adds users to groups
oc adm groups add-users developers leandro carlos hugo ana
oc adm groups add-users testers maria diego
oc adm groups add-users administrators mario
oc adm groups add-users test-approvers jose hernan
oc adm groups add-users prod-approvers hernan

# Sets permissions

# Project memberships
oc adm policy add-role-to-user admin leandro -n core-dev
oc adm policy add-role-to-user admin hugo -n core-dev
oc adm policy add-role-to-user admin leandro -n core-test
oc adm policy add-role-to-user admin hugo -n core-test

oc adm policy add-role-to-user admin carlos -n apis-dev
oc adm policy add-role-to-user admin ana -n apis-dev
oc adm policy add-role-to-user view carlos -n apis-test
oc adm policy add-role-to-user view ana -n apis-test

oc adm policy add-role-to-group admin administrators -n core-dev
oc adm policy add-role-to-group admin administrators -n apis-dev
oc adm policy add-role-to-group admin administrators -n core-test
oc adm policy add-role-to-group admin administrators -n apis-test
oc adm policy add-role-to-group admin administrators -n core-prod-management
oc adm policy add-role-to-group admin administrators -n apis-prod-management
oc adm policy add-role-to-group admin administrators -n jenkins
oc adm policy add-role-to-group admin administrators -n gogs

oc adm policy add-role-to-group edit prod-approvers -n jenkins
oc adm policy add-role-to-group edit test-approvers -n jenkins

# Exposes the non-prod cluster registry
minishift addons apply registry-route

# Creates the skopeo image

# Imports the jenkins slave base image
oc import-image jenkins-slave-base-rhel7 --confirm --from=registry.access.redhat.com/openshift3/jenkins-slave-base-rhel7 -n openshift

# Creates an image stream to hold the skopeo image
oc create is skopeo -n openshift

# Creates the build config
oc create -f ./configuration/jenkins/slaves/skopeo/skopeo-bc.yaml -n openshift

# Creates a new build
oc start-build skopeo -n openshift --wait

# Tags the skopeo image in the jenkins project 
oc tag openshift/skopeo:latest skopeo:latest -n jenkins

# Adds a label for the sync plugin to push the image into the jenkins instance
oc label is skopeo role=jenkins-slave -n jenkins

# Sets the MiniShift profile for the prod cluster
minishift profile set prod

# Starts the prod cluster
minishift start

# Logs in as admin to create projects
oc login https://$(minishift ip):8443 -u admin -p admin

# Creates the project where the admin sa will be
oc new-project prod-management

# Creates the prod projects
oc new-project core-prod
oc new-project apis-prod

# Creates an admin service account for deployments, etc
oc create sa admin -n prod-management

# Sets permissions
oc adm policy add-role-to-user admin system:serviceaccount:prod-management:admin -n core-prod
oc adm policy add-role-to-user admin system:serviceaccount:prod-management:admin -n apis-prod

# Exposes the prod cluster registry
minishift addons apply registry-route
