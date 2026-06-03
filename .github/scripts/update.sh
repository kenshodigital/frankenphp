#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Calculates composer checksum.
COMPOSER_CHECKSUM="$(
  curl --fail --silent \
    'https://getcomposer.org/download/latest-stable/composer.phar' \
  | shasum --algorithm 256 |  awk '{print $1}'
)"

# Works through templates and update definitions.
for template in .github/scripts/templates/*.yaml; do

  # Parses definition.
  definition="$(basename "${template}")"
  [[ "${definition}" =~ ^([0-9]+)-php([0-9]+\.[0-9]+)-([a-z]+) ]]
  frankenphp_version_major="${BASH_REMATCH[1]}"
  php_version="${BASH_REMATCH[2]//.}"
  base="${BASH_REMATCH[3]}"

  # Fetches keyfile for package repository.
  if [[ "${base}" == "alpine" ]]; then
    keyfile="$(
      curl \
        --clobber \
        --fail \
        --output-dir 'key/alpine' \
        --remote-header-name \
        --remote-name \
        --silent \
        --write-out '%{filename_effective}' \
        "https://pkg.henderkes.com/api/packages/${php_version}/alpine/key"
    )"
    KEYFILE="${keyfile#key/alpine/}"
  else
    curl \
      --fail \
      --output "key/debian/static-php${php_version}.asc" \
      --silent \
      "https://pkg.henderkes.com/api/packages/${php_version}/debian/repository.key"

    KEYFILE="static-php${php_version}.asc"
  fi

  # Fetches FrankenPHP package info from package repository.
  frankenphp_package_info="$(
    curl --fail --silent \
      "https://pkg.henderkes.com/api/v1/packages/${php_version}?type=${base}&q=frankenphp" \
    | jq --arg version "${frankenphp_version_major}" \
      '[.[] | select(.name == "frankenphp" and (.version | startswith($version + ".")))] | max_by(.created_at)'
  )"

  # Parses FrankenPHP version from package info.
  FRANKENPHP_PACKAGE_VERSION="$(echo "${frankenphp_package_info}" | jq --raw-output '.version')"
  [[ "${FRANKENPHP_PACKAGE_VERSION}" =~ ^[0-9]+\.([0-9]+)\.([0-9]+) ]]
  FRANKENPHP_VERSION_MINOR="${BASH_REMATCH[1]}"
  FRANKENPHP_VERSION_PATCH="${BASH_REMATCH[2]}"

  # Parses FrankenPHP release date from package info.
  frankenphp_package_date="$(echo "${frankenphp_package_info}" | jq --raw-output '.created_at')"
  [[ "${frankenphp_package_date}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
  frankenphp_release_date="${BASH_REMATCH[1]}"

  # Fetches PHP package info from package repository.
  php_package_info="$(
    curl --fail --silent \
      "https://pkg.henderkes.com/api/v1/packages/${php_version}?type=${base}&q=php-zts-embed" \
    | jq '[.[] | select(.name == "php-zts-embed")] | max_by(.created_at)'
  )"

  # Parses PHP version from package info.
  PHP_PACKAGE_VERSION="$(echo "${php_package_info}" | jq --raw-output '.version')"
  [[ "${PHP_PACKAGE_VERSION}" =~ ^[0-9]+\.[0-9]+\.([0-9]+) ]]
  PHP_VERSION_PATCH="${BASH_REMATCH[1]}"

  # Parses PHP release date from package info.
  php_package_date="$(echo "${php_package_info}" | jq --raw-output '.created_at')"
  [[ "${php_package_date}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
  php_release_date="${BASH_REMATCH[1]}"

  # Picks most recent release date.
  if [[ "${frankenphp_release_date}" > "${php_release_date}" ]]; then
    RELEASE_DATE="${frankenphp_release_date}"
  else
    RELEASE_DATE="${php_release_date}"
  fi

  # Exports variables for template.
  export PHP_VERSION_PATCH
  export FRANKENPHP_VERSION_MINOR
  export FRANKENPHP_VERSION_PATCH
  export RELEASE_DATE
  export KEYFILE
  export PHP_PACKAGE_VERSION
  export FRANKENPHP_PACKAGE_VERSION
  export COMPOSER_CHECKSUM

  # Renders template.
  # shellcheck disable=SC2016
  envsubst \
    '${PHP_VERSION_PATCH},${FRANKENPHP_VERSION_MINOR},${FRANKENPHP_VERSION_PATCH},${RELEASE_DATE},${KEYFILE},${PHP_PACKAGE_VERSION},${FRANKENPHP_PACKAGE_VERSION},${COMPOSER_CHECKSUM}' \
    < "${template}" \
    > "image/${definition}"
done
