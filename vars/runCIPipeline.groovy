#!/usr/bin/env groovy

def call(parameters) {
    pipeline {
        agent {
            label parameters.agent
        }
        options {
            skipDefaultCheckout()
            disableConcurrentBuilds()
        }
        stages {
            stage("Initialize") {
                steps {                    
                    script {
                        env.APP_NAME = parameters.appName
                        env.IMAGE_NAME = parameters.appName
        
                        env.DEV_PROJECT = "dev"
                                        
                        env.APP_TEMPLATE = (parameters.template) ? parameters.template : "./openshift/template.yaml"
                        env.APP_TEMPLATE_PARAMETERS_DEV = (parameters.templateParametersDev) ? parameters.templateParametersDev : "./openshift/environments/dev/templateParameters.txt"
                    }
                }
            }
            stage("Checkout") {
                steps {      
                    script {
                        env.GIT_COMMIT = checkout(scm).GIT_COMMIT
                    }
                }
            }
            stage("Compile") {
                steps {
                    sh parameters.compileCommands
                }
            }
            stage("Test") {
                steps {
                    sh parameters.testCommands
                }
            }
            stage("Build Image") {
                steps {
                    applyTemplate(project: env.DEV_PROJECT, 
                                application: env.APP_NAME, 
                                template: env.APP_TEMPLATE, 
                                parameters: env.APP_TEMPLATE_PARAMETERS_DEV,
                                createBuildObjects: true)

                    buildImage(project: env.DEV_PROJECT, 
                            application: env.APP_NAME, 
                            artifactsDir: parameters.artifactsDir)
                }
            }
            stage("Deploy DEV") {
                steps {
                    script {
                        env.TAG_NAME = getVersion(parameters.agent)
                    }   
                    
                    tagImage(srcProject: env.DEV_PROJECT, 
                            srcImage: env.IMAGE_NAME, 
                            srcTag: "latest", 
                            dstProject: env.DEV_PROJECT, 
                            dstImage: env.IMAGE_NAME,
                            dstTag: env.TAG_NAME)
                    
                    deployImage(project: env.DEV_PROJECT, 
                                application: env.APP_NAME, 
                                image: env.IMAGE_NAME, 
                                tag: env.TAG_NAME)
                }
            }
        }
    }    
}