  #!/bin/bash

set -x
echo "Pre scan setup"
# Pre scan setup
SONAR_PROJECT_NAME=$SONAR_PROJECT_KEY

echo "Begin monitoring the build & test"
# Begin monitoring the build & test
dotnet sonarscanner begin /key:$SONAR_PROJECT_NAME /d:sonar.host.url="$SONAR_HOST_URL" /d:sonar.login=$SONAR_AUTH_TOKEN /d:sonar.cs.opencover.reportsPaths="coverage.xml" /d:sonar.branch.name=$SOURCE_BRANCH /d:sonar.exclusions=$SONAR_EXCLUSIONS

dotnet clean
dotnet test $TEST_PATH/$PROJECT_FILE /p:CollectCoverage=true /p:CoverletOutputFormat=opencover --logger "trx;LogFileName=unittestresult.trx"

cp $TEST_PATH/TestResults/unittestresult.trx unittestresult
cp $TEST_PATH/coverage.opencover.xml coverage.xml

# End monitoring and submit results to SonarQube
dotnet sonarscanner end /d:sonar.login=$SONAR_AUTH_TOKEN
