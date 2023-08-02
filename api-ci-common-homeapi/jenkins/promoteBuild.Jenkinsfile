import groovy.json.*
import groovy.json.JsonSlurperClassic
def CLOUD_AGENT = cloudAgent.defaultCloudAgent()
def DOTNET_SDK_IMAGE = 'homehub-dotnet6.0-sdk-debian:0.8.0'


def artifactoryPromotion(sourceEnv, destinationEnv, serviceName, imageTag, destinationImageTag, copy, artifactType, artifactoryToken){
            def promoteAPIEndpoint = "$ArtiURL/artifactory/api/${artifactType}/homehub-${artifactType}-${sourceEnv}-local/v2/promote"
            def promotionRequest = "{\"targetRepo\" : \"homehub-${artifactType}-${destinationEnv}-local\", \"dockerRepository\" : \"/mortgages/${serviceName}\", \"tag\" : \"${imageTag}\",\"targetTag\" : \"${destinationImageTag}\",\"copy\": ${copy}}" 
            def result = sh(returnStdout: true, label: 'Promote Artifacts', script: "curl --location --request POST '${promoteAPIEndpoint}' --header 'Authorization: Bearer ${artifactoryToken}' --header 'Content-Type: application/json' -d '${promotionRequest}'")
    }


pipeline {
   agent {
        kubernetes {
            cloud CLOUD_AGENT
            defaultContainer 'jnlp'
            yaml dotnetBuildPod(image: DOTNET_SDK_IMAGE)
        }
    }

    environment {
        ARTIFACTORY_TOKEN_VAULT_KEY = 'artifactory_homehub_cicd_token'
        ARTIFACTORY_API_KEY = 'artifactory_homehub_cicd_api_key'
        HELM_BASE_URL ='$ArtiURL/artifactory'
    }

    parameters {
        choice (
            name: 'ARTIFACTORY_SOURCE_ENV',
            choices:[
                     'dev',
                     'stg',
                     'rel'
                    ],
            description: 'Service Name which needs to be copied or moved from one repo to another')
        choice (
            name: 'ARTIFACTORY_DESTINATION_ENV',
            choices:[
                     'dev',
                     'stg',
                     'rel', 
                    ],
            description: 'Service Name which needs to be copied or moved from one repo to another')
        choice (
            name: 'SERVICE_NAME',
            choices:[
                'nbs-mortgages-intermediary-authmanager'
                ,'nbs-mortgages-copytextmanager'
                ,'nbs-mortgages-stub-icm'
            ],
            description: 'Artifact Name which needs to be copied or moved from one repo to another')
        string (
            name: 'IMAGE_TAG',
            defaultValue: '1.4.0-35',
            description: 'Artifact Tag')
        string (
            name: 'DESTINATION_IMAGE_TAG',
            defaultValue: '1.4.0-15',
            description: 'Destination Artifact Tag')
        booleanParam(
            name: 'COPY', 
            defaultValue: true,
            description: 'Select to copy the artifact from source repo to destination repo in artifactory')
    }
    stages {     

        stage('Helm Chart Promotion') {
            steps {
                script {
                    withVault(vaultSecrets: [[engineVersion: 2, path: 'secrets/cbjenkins', secretValues: [
                        [envVar: 'ARTIFACTORY_KEY', vaultKey: ARTIFACTORY_API_KEY]]]])
                    {
                        sh """
                            curl '${HELM_BASE_URL}/homehub-helm-${ARTIFACTORY_SOURCE_ENV}/${SERVICE_NAME}/${IMAGE_TAG}/${SERVICE_NAME}-${IMAGE_TAG}.tgz' \
                                    -H 'X-JFrog-Art-Api:${ARTIFACTORY_KEY}' \
                                    -o '${SERVICE_NAME}-${DESTINATION_IMAGE_TAG}.tgz'

                            curl '${HELM_BASE_URL}/homehub-helm-${ARTIFACTORY_DESTINATION_ENV}/${SERVICE_NAME}/${DESTINATION_IMAGE_TAG}/' \
                                    -H "X-JFrog-Art-Api:${ARTIFACTORY_KEY}" \
                                    -T '$WORKSPACE/${SERVICE_NAME}-${DESTINATION_IMAGE_TAG}.tgz'
                        """
                    }
                }
            }
        }
        stage('Image Promotion') {
            steps {
                script{
                    container(name: 'jnlp') {
                            withEnv(['PATH+EXTRA=/busybox']) {
                                withVault(vaultSecrets: [[engineVersion: 2, path: 'secrets/cbjenkins', secretValues: [
                                [envVar: 'ARTIFACTORY_TOKEN', vaultKey: "${ARTIFACTORY_TOKEN_VAULT_KEY}"]]]])
                                {
                                    artifactoryPromotion(params.ARTIFACTORY_SOURCE_ENV, params.ARTIFACTORY_DESTINATION_ENV, params.SERVICE_NAME, params.IMAGE_TAG, params.DESTINATION_IMAGE_TAG, params.COPY, "docker", "${ARTIFACTORY_TOKEN}")
                                }
                            }
                        }
                }
            }
        }
    }
    
}