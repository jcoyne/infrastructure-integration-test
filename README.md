[![Build Status](https://travis-ci.org/sul-dlss/infrastructure-integration-test.svg?branch=master)](https://travis-ci.org/sul-dlss/infrastructure-integration-test)

# SDR Integration Tests

This script drives a browser to do inter-system integration testing of SDR in the staging environment.

## Installation

This script depends on having Firefox downloaded.

1. `bundle install`
1. Download geckodriver `curl -L --output geckodriver-v0.26.0-macos.tar.gz https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-macos.tar.gz`
1. Uncompress it `tar -zxvf geckodriver-v0.26.0-macos.tar.gz`
1. Put geckodriver on the path `export PATH=$PATH:$(pwd)`

## Prerequisites

1. Connect to Stanford VPN (full-tunnel or split-tunnel)
1. Ensure you have a valid, non-expired Kerberos ticket (use `klist` to verify, or run `kinit` to refresh)
1. Configure your SSH client to allow delegation of Kerberos credentials (required for any tests that use `scp`), by adding the following to `~/.ssh/config` or wherever your system stores SSH configuration:

```
# Add to appropriate place, such as:
Host *.stanford.edu
    GSSAPIDelegateCredentials yes
```

### ETD Credentials

In order to run the tests in `spec/features/create_etd_spec.rb`, you will need to specify credentials required to authenticate connections to the ETD application. In order to do this, copy `settings.yml` to `settings.local.yml` and set the ETD username and password to the [values expected in our staging environment](https://github.com/sul-dlss/shared_configs/blob/a90c636b968a1ede4886a61dadc799dd5d162fe1/config/settings/production.yml#L34-L35).

**NOTE**: `settings.local.yml` is ignored by git and should remain so. Please do not accidentally add this file to version control.

## Run Tests

`bundle exec rspec`

You will be prompted to type in your Stanford credentials and will then need to approve a multi-factor authentication push.

## Add New Tests

Please use the integration-testing APO and collection when feasible:
- integration-testing APO: druid:qc410yz8746
- integration-testing collection: druid:bc778pm9866
