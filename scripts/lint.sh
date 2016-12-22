#!/bin/bash 
# lint.sh
#
# "Linting is the process of running a program that will analyse code for potential errors."
#
# Author: Joël Franusic (joel.franusic@okta.com)
# Copyright 2016 Okta, Inc.

# Quit if any of the commands in this script fail
set -e

# `cd` to the path where Okta's build system has this repository
cd ${OKTA_HOME}/${REPO}

GENERATED_SITE_LOCATION="_site"

# Print an easily visible line, useful for log files.
function interject {
    echo "----- ${1} -----"
    }

function setup {
    interject 'Installing dependencies'
    # Install the version of Ruby that we all use.
    #
    # Note: The file `.ruby-version` has the current ruby version and is used by rbenv
    # https://rvm.io/workflow/projects#project-file-ruby-version
    # For example, this file might contain this line: "ruby-2.0.0-p643"
    rvm install `cat .ruby-version`
    # "source" the version of Ruby that we installed, so the "gem" and "bundle"
    # commands use the version of Ruby that we want.
    # https://rvm.io/rvm/basics#post-install-configuration
    source $(rvm `cat .ruby-version` do rvm env --path)
    # Install bundler
    gem install bundler
    # Install the gems needed for Jekyll
    bundle install
    interject 'Done installing dependencies'
    interject 'Building Jekyll website'
    # Build the Jekyll website
    bundle exec jekyll build
    local status=$?
    interject 'Done building Jekyll website'
    return $status
    }

function url_consistency_check() {
    interject "Checking ${GENERATED_SITE_LOCATION} to make sure documentation does not include '/api/v1' in example URLs"
    if [ ! -d "$GENERATED_SITE_LOCATION" ]; then
       echo "Directory ${GENERATED_SITE_LOCATION} not found";
       return 1;
    fi

    url_consistency_check_file=`mktemp`
    # Search the _site directory for all files (-type f) ending in .html (-iname '*.html')
    find $GENERATED_SITE_LOCATION -type f -iname '*.html' | \
        # 'grep' all found files for 'api-uri-template', printing line numbers on output
        xargs grep --line-number api-uri-template | \
        # Search for the 'api/v' string, so we match "api/v1", "api/v2", etc
        grep api/v | \
        # The 'sed' command below pulls out the filename (\1), the line number (\2) and the URL path (\3)
        # For example, this:
        # _site/docs/api/resources/authn.html:2278:<p><span class="api-uri-template api-uri-post"><span class="api-label">POST</span> /api/v1/authn</span></p>
        # becomes this:
        # _site/docs/api/resources/authn.html:2278:/api/v1/authn
        sed -e 's/^\([^:]*\):\([^:]*\).*<\/span> \(.*\)<\/span>.*/\1:\2:\3/' | \
        # Write the results to STDOUT and the $url_consistency_check_file
        tee $url_consistency_check_file
    interject "Done checking $GENERATED_SITE_LOCATION for URLs with '/api/v1'"
    # Set the exit status to "1" if no lines were selected.
    # From the man page for grep(1):
    # EXIT STATUS
    #     The grep utility exits with one of the following values:
    # 
    #     0     One or more lines were selected.
    #     1     No lines were selected.
    #     >1    An error occurred.
    grep . $url_consistency_check_file > /dev/null
}

interject "Running lint.sh in $(pwd)"
if ! setup;
then
    echo "Error building site"
    exit $BUILD_FAILURE;
fi

if url_consistency_check;
then
    echo "FAILURE!"
    exit $BUILD_FAILURE;
fi

exit $SUCCESS;
