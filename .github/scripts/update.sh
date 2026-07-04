#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Checks if a given package is available
# on a given platform for a given version.
check_platforms() {
  case "${2}" in
    alpine)
      curl --fail --silent \
        "https://pkg.henderkes.com/api/packages/${1}/alpine/main/php-zts/x86_64/APKINDEX.tar.gz" \
        | gzip --decompress \
        | tar -xO 2>/dev/null \
        | strings \
        | grep --after-context=1 "^P:${3}$" \
        | grep --fixed-strings --line-regexp --quiet "V:${4}" \
      && \
      curl --fail --silent \
        "https://pkg.henderkes.com/api/packages/${1}/alpine/main/php-zts/aarch64/APKINDEX.tar.gz" \
        | gzip --decompress \
        | tar -xO 2>/dev/null \
        | strings \
        | grep --after-context=1 "^P:${3}$" \
        | grep --fixed-strings --line-regexp --quiet "V:${4}"
      ;;
    debian)
      curl --fail --silent \
        "https://pkg.henderkes.com/api/packages/${1}/debian/dists/php-zts/main/binary-amd64/Packages" \
        | grep --after-context=1 "^Package: ${3}$" \
        | grep --fixed-strings --line-regexp --quiet "Version: ${4}" \
      && \
      curl --fail --silent \
        "https://pkg.henderkes.com/api/packages/${1}/debian/dists/php-zts/main/binary-arm64/Packages" \
        | grep --after-context=1 "^Package: ${3}$" \
        | grep --fixed-strings --line-regexp --quiet "Version: ${4}"
      ;;
    *)
      exit 1
      ;;
  esac
}

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
  case "${base}" in
    alpine)
      KEYFILE="$(
        curl \
          --clobber \
          --fail \
          --output-dir 'key/alpine' \
          --remote-header-name \
          --remote-name \
          --silent \
          --write-out '%{filename_effective}' \
          "https://pkg.henderkes.com/api/packages/${php_version}/alpine/key" \
          | sed 's|^key/alpine/||'
      )"
      ;;
    debian)
      KEYFILE="$(
        curl \
          --fail \
          --output "key/debian/static-php${php_version}.asc" \
          --silent \
          --write-out '%{filename_effective}' \
          "https://pkg.henderkes.com/api/packages/${php_version}/debian/repository.key" \
          | sed 's|^key/debian/||'
      )"
      ;;
    *)
      exit 1
      ;;
  esac

  # Gets previous versions from existing definition.
  RELEASE_DATE="$(
    grep '^[[:space:]]*RELEASE_DATE:' "image/${definition}" 2>/dev/null \
      | cut -d: -f2- \
      | xargs \
      || true
  )"
  FRANKENPHP_PACKAGE_VERSION="$(
    grep '^[[:space:]]*FRANKENPHP_PACKAGE_VERSION:' "image/${definition}" 2>/dev/null \
      | cut -d: -f2- \
      | xargs \
      || true
  )"
  PHP_PACKAGE_VERSION="$(
    grep '^[[:space:]]*PHP_PACKAGE_VERSION:' "image/${definition}" 2>/dev/null \
      | cut -d: -f2- \
      | xargs \
      || true
  )"

  # Fetches FrankenPHP package info from package repository.
  frankenphp_package_info="$(
    curl --fail --silent \
      "https://pkg.henderkes.com/api/v1/packages/${php_version}?type=${base}&q=frankenphp" \
    | jq --arg version "${frankenphp_version_major}" \
      '[.[] | select(.name == "frankenphp" and (.version | startswith($version + ".")))] | max_by(.created_at)'
  )"

  # Parses latest FrankenPHP version from package info.
  frankenphp_package_version_latest="$(echo "${frankenphp_package_info}" | jq --raw-output '.version')"

  # Checks if latest FrankenPHP version is available for
  # all platforms. Falls back on previous version otherwise.
  if check_platforms "${php_version}" "${base}" 'frankenphp' "${frankenphp_package_version_latest}"; then

    FRANKENPHP_PACKAGE_VERSION="${frankenphp_package_version_latest}"

    # Parses latest FrankenPHP release date from package info.
    frankenphp_package_date="$(echo "${frankenphp_package_info}" | jq --raw-output '.created_at')"
    [[ "${frankenphp_package_date}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
    if [[ "${BASH_REMATCH[1]}" > "${RELEASE_DATE}" ]]; then
      RELEASE_DATE="${BASH_REMATCH[1]}"
    fi
  elif [[ -z "${FRANKENPHP_PACKAGE_VERSION}" ]]; then
    # Skips definition if FrankenPHP is not available on first run.
    continue
  fi

  [[ "${FRANKENPHP_PACKAGE_VERSION}" =~ ^[0-9]+\.([0-9]+)\.([0-9]+) ]]
  FRANKENPHP_VERSION_MINOR="${BASH_REMATCH[1]}"
  FRANKENPHP_VERSION_PATCH="${BASH_REMATCH[2]}"

  # Fetches PHP package info from package repository.
  php_package_info="$(
    curl --fail --silent \
      "https://pkg.henderkes.com/api/v1/packages/${php_version}?type=${base}&q=php-zts-embed" \
    | jq '[.[] | select(.name == "php-zts-embed")] | max_by(.created_at)'
  )"

  # Parses latest PHP version from package info.
  php_package_version_latest="$(echo "${php_package_info}" | jq --raw-output '.version')"

  # Checks if latest PHP version is available for all
  # platforms. Falls back on previous version otherwise.
  if check_platforms "${php_version}" "${base}" 'php-zts-embed' "${php_package_version_latest}"; then

    PHP_PACKAGE_VERSION="${php_package_version_latest}"

    # Parses latest PHP release date from package info.
    php_package_date="$(echo "${php_package_info}" | jq --raw-output '.created_at')"
    [[ "${php_package_date}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]

    # Picks most recent release date.
    if [[ "${BASH_REMATCH[1]}" > "${RELEASE_DATE}" ]]; then
      RELEASE_DATE="${BASH_REMATCH[1]}"
    fi
  elif [[ -z "${PHP_PACKAGE_VERSION}" ]]; then
    # Skips definition if PHP is not available on first run.
    continue
  fi

  [[ "${PHP_PACKAGE_VERSION}" =~ ^[0-9]+\.[0-9]+\.([0-9]+) ]]
  PHP_VERSION_PATCH="${BASH_REMATCH[1]}"

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
