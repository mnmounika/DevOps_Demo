def ARTIFACTORY_REPO = 'homehub-docker-dev-local.artifactory'
def ARTIFACTORY_USER_KEY = 'artifactory_homehub_ci_user'
def ARTIFACTORY_PASS_KEY = 'artifactory_homehub_ci_password'
def ARTIFACTORY_CI_EMAIL_KEY = 'artifactory_homehub_ci_email'
def ARTIFACTORY_CI_AUTH_KEY = 'artifactory_homehub_ci_auth'

// Using debian image because Mongo2Go fails with Alpine due to an open issue.
def DOTNET_SDK_IMAGE = 'homehub-dotnet6.0-sdk-debian:0.8.0'
def SONAR_AUTH_KEY = 'sonarqube_api_key'
def KMAAS_SECRET_PATH = 'secrets/cbjenkins'
def SONAR_HOST_URL = "https://sonarqube"
def SNYK_ORG = 'snyk_digitalhomehub'
def SONAR_EXCLUSIONS = '**/*Program.cs,**/*Startup.cs,**/Migrations/*,**/*AppSettings.cs,**/*Extension.cs,**/*ServiceKey*.cs,**/*ModifyConfigurations.cs,**/*Stub*.cs,**/HealthCheck/*.cs'
def CLOUD_AGENT = cloudAgent.defaultCloudAgent()
def KANIKO_AGENT = cloudAgent.defaultKanikoAgent()
def DOCKER_FILE
def SOURCE_BRANCH
def TEST_PATH
def PROJECT_FILE

pipeline {

    options {
        skipDefaultCheckout()
    }
    
    parameters  {
        choice (
            name: 'SERVICE_NAME', 
            choices: [
                'service-a'
                ,'service-b'
                ,'service-c'
            ], 
            description: 'Service to build')
        string (
            name: 'GIT_SOURCE_BRANCH',
            defaultValue: 'home-api-cloud-migration/ft1/feature',
            description: 'Source code branch')
        booleanParam (
            name: 'RUN_UNIT_TESTS_SONAR',
            defaultValue: false,
            description: 'Select to run unit tests')
        booleanParam(
            name: 'RUN_SNYK_ANALYSIS',
            defaultValue: false,
            description: 'Select to run SNYK analysis')
    }

    agent {
        kubernetes {
            cloud CLOUD_AGENT
            defaultContainer 'jnlp'
            yaml dotnetBuildPod(image: DOTNET_SDK_IMAGE)
        }
    }

    stages {
        stage('Checkout SCM') {
            steps {
                script {
                    GIT_REPO_URL = "https://github.com/" + SERVICE_NAME + ".git"
                    checkout([$class: 'GitSCM', 
                        branches: [[name: "${GIT_SOURCE_BRANCH}"]],
                        doGenerateSubmoduleConfigurations: false,
                        userRemoteConfigs: [[credentialsId: 'cbj_github_pat_userpass', url: "${GIT_REPO_URL}"]]])
                    
                    if (params.RUN_UNIT_TESTS_SONAR == true) {
                        dir("api-ci-common"){
                            echo "Getting service config."
                            checkout scm
                            def jsonObj = readJSON file: "./resources/services.json"
                            TEST_PATH = jsonObj["${SERVICE_NAME}"]['TestPath']
                            PROJECT_FILE = jsonObj["${SERVICE_NAME}"]['ProjectFile']
                        }
                    }
                }
            }
        }

        stage('Preperation') {
            steps {
                script {
                    
                    DOCKER_FILE = "docker/Dockerfile"
                    SOURCE_BRANCH = GIT_SOURCE_BRANCH
                    APP_VERSION = sh(returnStdout: true, script: "(cat src/Directory.Build.props | grep '<Version>' | awk -F '[<|>]' '{print \$3}' | sed 's/[\",]//g' | tr -d '[[:space:]]')")
                    BUILD_VERSION="${APP_VERSION}-${BUILD_NUMBER}"
                    GIT_COMMIT_HASH = sh (script: "git log -n 1 --pretty=format:'%H'", returnStdout: true)
                }
            }
        }

        stage('Unit Tests + Sonar Scan') {
            when {
                expression { params.RUN_UNIT_TESTS_SONAR }
            }
            steps {
                container(name: 'dotnet-agent') {
                    withSonarQubeEnv('sonarqube') {
                        withEnv([
                                "SONAR_PROJECT_KEY=homehub.${SERVICE_NAME}",
                                "SONAR_HOST_URL=${SONAR_HOST_URL}",
                                "SONAR_EXCLUSIONS=${SONAR_EXCLUSIONS}",
                                "SOURCE_BRANCH=${SOURCE_BRANCH}",
                                "TEST_PATH=${TEST_PATH}",
                                "PROJECT_FILE=${PROJECT_FILE}"
                                ]) {
                            withVault(vaultSecrets: [[engineVersion: 2, path: KMAAS_SECRET_PATH, secretValues: [
                                [envVar: 'SONAR_AUTH_TOKEN', vaultKey: SONAR_AUTH_KEY],
                                [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                                [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                            {
                                sh '''
                                    . ./api-ci-common/resources/run-sonarqube.sh
                                    sleep 10
                                '''
                            }
                        }
                    }
                    sonarDotNetGate([projectKey: "homehub.${SERVICE_NAME}"])
                }
            }
        }

        stage('Publish') {
            steps {
                script {
                    container(name: 'dotnet-agent') {
                        withVault(vaultSecrets: [[engineVersion: 2, path: 'secrets/cbjenkins', secretValues: [
                                [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                                [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                        {
                            sh """
                                dotnet publish --output output --configuration Release
                            """
                        }
                    }
                    stash name: 'branch_root', includes:'docker/**,helm3/**,output/**'
                }
            }
        }

        stage('Snyk Analysis') {
            when {
                expression { params.RUN_SNYK_ANALYSIS} 
            }
            steps {
                script {   
                    def solutionFile = findFiles(glob: '**/*.sln')
                    def solutionFilePath = solutionFile[0].path 
                    snykScan( organisation: SNYK_ORG,
                              snykApiTokenId: 'cbj_snyk_api_key',
                              severity: 'high',
                              failOnIssues: 'false',
                              targetFile: solutionFilePath,
                              additionalArguments: '--project-tags=team=API  --target-reference=$SERVICE_NAME --remote-repo-url=$SERVICE_NAME')
                }
            }
        }
        
        stage('Package Helm Charts') {
            agent {
                kubernetes {
                    cloud CLOUD_AGENT
                    defaultContainer 'jnlp'
                    yaml helm3Pod(uid: '10020')
                }
            }
            steps {
                script {
                    container(name: 'helm3') {
                        withVault(vaultSecrets: [[engineVersion: 2, path: KMAAS_SECRET_PATH, secretValues: [
                                [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                                [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                        {
                            unstash 'branch_root'

                            sh """
                                helm package helm3/charts/ --version $BUILD_VERSION
                            """
                            stash name:'helm', includes:'*.tgz'
                        }
                    }
                }
            }
        }

        stage('Build & Push Image') {
            agent {
                kubernetes {
                    cloud KANIKO_AGENT
                    defaultContainer 'jnlp'
                    yaml kanikoPod()
                }
            }
            steps {
                script {
                    unstash 'branch_root'
                    APP_IMAGE_NAME="${ARTIFACTORY_REPO}/mortgages/${SERVICE_NAME}:${BUILD_VERSION}"

                    container(name: 'kaniko', shell: '/busybox/sh') {
                        withEnv(['PATH+EXTRA=/busybox']) {
                            withVault(vaultSecrets: [[engineVersion: 2, path: KMAAS_SECRET_PATH, secretValues: [
                                [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                                [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY],
                                [envVar: 'ARTIFACTORY_CI_AUTH', vaultKey: ARTIFACTORY_CI_AUTH_KEY],
                                [envVar: 'ARTIFACTORY_CI_EMAIL', vaultKey: ARTIFACTORY_CI_EMAIL_KEY]]]])
                            {

                                sh """
                                    echo '{"auths": {"'$ARTIFACTORY_REPO'":{"email": "'$ARTIFACTORY_CI_EMAIL'", "auth": "'$ARTIFACTORY_CI_AUTH'"}}}' > /kaniko/.docker/config.json
                                    
                                    /kaniko/executor \
                                        --context="`pwd`" \
                                        --dockerfile=$DOCKER_FILE \
                                        --skip-unused-stages \
                                        --destination=$APP_IMAGE_NAME \
                                        --build-arg ARTIFACTORY_USER="$ARTIFACTORY_USER" \
                                        --build-arg ARTIFACTORY_PASS="$ARTIFACTORY_PASS" \
                                        --label sourceBranch=$GIT_SOURCE_BRANCH \
                                        --label sourceCommit=$GIT_COMMIT_HASH \
                                        --skip-tls-verify \
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Push Helm Charts') {
            steps {
                script {
                    container(name: 'jnlp') {
                        withVault(vaultSecrets: [[engineVersion: 2, path: KMAAS_SECRET_PATH, secretValues: [
                                [envVar: 'ARTIFACTORY_USER', vaultKey: ARTIFACTORY_USER_KEY],
                                [envVar: 'ARTIFACTORY_PASS', vaultKey: ARTIFACTORY_PASS_KEY]]]])
                        {
                            unstash 'helm'
                            sh """
                                curl "$ARTIURL/homehub-helm-dev/${SERVICE_NAME}/${BUILD_VERSION}/" \
                                    -H "X-JFrog-Art-Api:value" \
                                    -T $WORKSPACE/${SERVICE_NAME}-${BUILD_VERSION}.tgz 
                            """
                        }
                    }
                }
            }
        }
    }
}
