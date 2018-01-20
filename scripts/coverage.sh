#!/bin/bash

PROJECT="Promise"

if [[ -z "${TRAVIS_JOB_ID}" ]]; then
    echo "TRAVIS_JOB_ID is not defined."

else if [[ -z "${CODECOV_TOKEN}" ]]; then
    echo "CODECOV_TOKEN is not defined."

else
    # Generate xcodeproj
    swift package generate-xcodeproj --enable-code-coverage

    # Open Xcode
    open $PROJECT.xcodeproj

    # Test
    xcodebuild \
        -scheme $PROJECT-Package \
        -sdk macosx \
        -configuration Release \
        -enableCodeCoverage YES \
        test

    # Show coverage
    slather coverage --show \
        --scheme $PROJECT-Package \
        --ignore Tests/**/* \
        $PROJECT.xcodeproj

    # Post to Coveralls
    slather coverage \
        --scheme $PROJECT-Package \
        --ignore Tests/**/* \
        -c \
        ./$PROJECT.xcodeproj/

    # Generate coverage report for codecov
    slather coverage \
        --scheme $PROJECT-Package \
        --ignore Tests/**/* \
        -x \
        --output-directory .coverage \
        ./$PROJECT.xcodeproj/

    # Post coverage to codecov
    curl -s https://codecov.io/bash > .coverage/codecov.sh
    bash .coverage/codecov.sh \
        -f .coverage/cobertura.xml \
        -X coveragepy \
        -X gcov \
        -X xcode \
        -t $CODECOV_TOKEN

    # Clean
    rm -r .coverage
    rm -r $PROJECT.xcodeproj
fi