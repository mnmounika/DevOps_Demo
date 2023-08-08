def HELM_REPO = '$ARTIURL/:443/artifactory/api/helm/'
def HELM_URL = '$ARTIURL/artifactory/'
def MANIFEST_REPO_NAME ='homehub-docker-dev'
def HELM_REPO_NAME = 'homehub-helm-dev'
def ARTIFACTORY_USER_KEY = 'artifactory_homehub_ci_user'
def ARTIFACTORY_PASS_KEY = 'artifactory_homehub_ci_api_key'
def IMAGE_BRANCH = ""
def IMAGE_COMMIT = ""

pipeline {
    
    options {
        skipDefaultCheckout()
    }

    agent {
        kubernetes {
            cloud defaultAgent()
            defaultContainer 'helm3'
            yaml helm3Pod()
        }
    }

    parameters {
        choice (
            name: 'SERVICE_NAME',
            choices:[
                'Service-A'
                ,'Service-B'
                ,'Service-C'
            ],
            description: 'Service Name which needs to be deployed')
        string (
            name: 'IMAGE_TAG',
            defaultValue: '1.4.0-88',
            description: 'Version of the release with build number which created the image')
        choice (
            name: 'NAMESPACE',
            choices:[
                'api-dev-01','api-dev-02','api-dev-03'
                ,'dip-dev-common-01','dip-dev-common-02','dip-dev-common-03'
                ,'api-sit-01','api-sit-02','api-sit-03'
                ,'dip-sit-common-01','dip-sit-common-02','dip-sit-common-03'
                ,'api-pre-01','dip-pre-common-01'
            ],
            description: 'Namesapce where image will be deployed')
        choice(
            name: 'CLUSTER', 
            choices: ['dev', 'tst'],
            description: 'Cluster name')
    }

    stages {
        stage('Preperation') {
            steps {
                script {
                    container(name: 'jnlp') {

                        if (CLUSTER == 'tst') {
                            MANIFEST_REPO_NAME ='homehub-docker-stg'
                            HELM_REPO_NAME = 'homehub-helm-stg'
                        }
                        
                        try {
                            MANIFEST_URL = "$ARTIURL/${MANIFEST_REPO_NAME}/mortgages/${SERVICE_NAME}/${IMAGE_TAG}/manifest.json?properties"
                            IMAGE_MANIFEST =  sh (
                                script: "curl -H 'X-JFrog-Art-Api:AKCp8krVQjz1hoAiQzW68HdrouiDgcydvXAQkxX1CYVEHeXq7hWbyJenTd3EMTLhasDuwAuNe' $MANIFEST_URL", 
                                returnStdout: true
                            )
                            IMAGE_PROPERTIES = readJSON text: IMAGE_MANIFEST
                            IMAGE_BRANCH = IMAGE_PROPERTIES.properties['docker.label.sourceBranch'][0]
                            IMAGE_COMMIT = IMAGE_PROPERTIES.properties['docker.label.sourceCommit'][0]
                        }
                        catch (all) {
                            echo "ERROR RETRIEVING IMAGE LABELS"
                            echo "DEPLOYMENT WILL PROCCEED WITH BLANK LABELS"
                        }
                        withVault(vaultSecrets: [[engineVersion: 2, path: 'secrets/cbjenkins', secretValues: [
                            [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                        {
                            sh """
                                curl -sSf -H 'X-JFrog-Art-Api:${ARTIFACTORY_PASS}' -O '${HELM_URL}${HELM_REPO_NAME}/${SERVICE_NAME}/${IMAGE_TAG}/${SERVICE_NAME}-${IMAGE_TAG}.tgz'
                                tar -xf ${SERVICE_NAME}-${IMAGE_TAG}.tgz
                                ls -l
                            """
                        }
                    }
                }
            } 
        }
        stage('Helm Upgrade') {
            steps {
                script {
                    withVault(vaultSecrets: [[engineVersion: 2, path: 'secrets/cbjenkins', secretValues: [
                        [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                        [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                    {
                        sh """
                            # TODO: Helm requires write access to directorys in home. Temp solution is to set dirs to temp.
                            export HELM_CONFIG_HOME=/tmp
                            export HELM_CACHE_HOME=/tmp
                            export HELM_DATA_HOME=/tmp
                            
                            helm repo add ${HELM_REPO_NAME} ${HELM_REPO}${HELM_REPO_NAME} \
                                --username ${ARTIFACTORY_USER} \
                                --password ${ARTIFACTORY_PASS} \
                                --insecure-skip-tls-verify \
                                --debug
                            
                            helm repo update

                            helm upgrade ${SERVICE_NAME} ${HELM_REPO_NAME}/${SERVICE_NAME} \
                                --values ${SERVICE_NAME}/values/${NAMESPACE}.yaml \
                                --namespace=${NAMESPACE} \
                                --username ${ARTIFACTORY_USER} \
                                --password ${ARTIFACTORY_PASS} \
                                --insecure-skip-tls-verify  \
                                --version ${IMAGE_TAG} \
                                --debug --install --force \
                                --set IMAGE_TAG=${IMAGE_TAG} \
                                --set IMAGE_BRANCH=${IMAGE_BRANCH} \
                                --set IMAGE_COMMIT=${IMAGE_COMMIT} \
                                --set CLUSTER=${defaultCluster()}
                        """
                    }
                }
            }
        }
    }
}

def defaultAgent() {
    return params.CLUSTER == 'tst' ? cloudAgent.defaultCloudTestAgent() : cloudAgent.defaultCloudAgent()
}

def defaultCluster() {
    def agent = defaultAgent()
    return "hh-${params.CLUSTER}-${agent.contains('02') ? '02' : '01'}"
}
