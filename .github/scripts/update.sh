#!/bin/bash
set -euo pipefail
shopt -s nullglob
IFS=$'\n\t'

# Works through templates and update definitions.
for template in .github/scripts/templates/*.yaml; do

  # Maps definition.
  definition="$(basename "${template}" ".yaml")"

  # Parses version constraints and base.
  [[ "${definition}" =~ ^([0-9]+)-php([0-9]+\.[0-9]+)-([a-z]+[0-9.]*[0-9](-dev)?)$ ]]
  frankenphp_version_major="${BASH_REMATCH[1]}"
  php_version_major_minor="${BASH_REMATCH[2]}"
  base="${BASH_REMATCH[3]}"
  dev="${BASH_REMATCH[4]}"


  # Fetches FrankenPHP release info from repository.
  frankenphp_release="$(
    curl --fail --silent \
      "https://api.github.com/repos/php/frankenphp/releases" \
    | jq \
      --arg prefix "v${frankenphp_version_major}." \
      '[.[] | select(.tag_name | startswith($prefix)) | select(.prerelease == false and .draft == false)] | first'
  )"

  # Parses latest FrankenPHP tag from release info.
  frankenphp_release_tag="$(echo "${frankenphp_release}" | jq --raw-output '.tag_name')"
  [[ "${frankenphp_release_tag}" =~ ^v((([0-9]+)\.[0-9]+)\.[0-9]+)$ ]]
  FRANKENPHP_VERSION="${BASH_REMATCH[1]}"
  FRANKENPHP_VERSION_MAJOR_MINOR="${BASH_REMATCH[2]}"
  FRANKENPHP_VERSION_MAJOR="${BASH_REMATCH[3]}"

  # Parses latest FrankenPHP release date from release info.
  frankenphp_release_published="$(echo "${frankenphp_release}" | jq --raw-output '.published_at')"
  [[ "${frankenphp_release_published}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
  RELEASE_DATE="${BASH_REMATCH[1]}"


  # Fetches PHP release info from repository.
  php_release="$(
    curl --fail --silent \
      "https://api.github.com/repos/php/php-src/releases" \
    | jq \
      --arg prefix "php-${php_version_major_minor}." \
      '[.[] | select(.tag_name | startswith($prefix)) | select(.prerelease == false and .draft == false)] | first'
  )"

  # Parses latest PHP tag from release info.
  php_release_tag="$(echo "${php_release}" | jq --raw-output '.tag_name')"
  [[ "${php_release_tag}" =~ ^php-(([0-9]+\.[0-9]+)\.[0-9]+)$ ]]
  PHP_VERSION="${BASH_REMATCH[1]}"
  PHP_VERSION_MAJOR_MINOR="${BASH_REMATCH[2]}"

  # Parses latest PHP release date from release info.
  php_release_published="$(echo "${php_release}" | jq --raw-output '.published_at')"
  [[ "${php_release_published}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
  if [[ "${BASH_REMATCH[1]}" > "${RELEASE_DATE}" ]]; then
    RELEASE_DATE="${BASH_REMATCH[1]}"
  fi


  # Fetches Composer release info from repository.
  if [[ -n "${dev}" ]]; then
    composer_release="$(
      curl --fail --silent \
        "https://api.github.com/repos/composer/composer/releases" \
      | jq '[.[] | select(.prerelease == false and .draft == false)] | first'
    )"

    # Parses latest Composer tag from release info.
    composer_release_tag="$(echo "${composer_release}" | jq --raw-output '.tag_name')"
    [[ "${composer_release_tag}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]
    COMPOSER_VERSION="${BASH_REMATCH[1]}"

    # Parses latest Composer release date from release info.
    composer_release_published="$(echo "${composer_release}" | jq --raw-output '.published_at')"
    [[ "${composer_release_published}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]
    if [[ "${BASH_REMATCH[1]}" > "${RELEASE_DATE}" ]]; then
      RELEASE_DATE="${BASH_REMATCH[1]}"
    fi
  else
    COMPOSER_VERSION=""
  fi

  # Exports variables for template.
  export FRANKENPHP_VERSION
  export FRANKENPHP_VERSION_MAJOR
  export FRANKENPHP_VERSION_MAJOR_MINOR
  export PHP_VERSION
  export PHP_VERSION_MAJOR_MINOR
  export COMPOSER_VERSION
  export RELEASE_DATE

  # Renders template.
  # shellcheck disable=SC2016
  envsubst \
    '${FRANKENPHP_VERSION},${FRANKENPHP_VERSION_MAJOR},${FRANKENPHP_VERSION_MAJOR_MINOR},${PHP_VERSION},${PHP_VERSION_MAJOR_MINOR},${COMPOSER_VERSION},${RELEASE_DATE}' \
    < "${template}" \
    > "image/${definition}.yaml"


  # Checks for changes, updates
  # repository and dispatches build.
  if [[ "${CI:-}" == "true" && -n "$(git status --porcelain)" ]]; then

    # Commits changes.
    git add image
    git commit -m "Updates definition ${definition}"

    # Prepares tag.
    tag="${FRANKENPHP_VERSION}-php${PHP_VERSION}-${base}"

    # Pushes changes. Rebases, waits and
    # retries three times on conflict.
    for _ in 1 2 3; do
      if git push; then

        # Adds or updates tag.
        git tag -f "${tag}"
        git push -f --tags

        # Dispatches build.
        gh workflow run build.yaml \
          --field definition="${definition}" \
          --ref "${tag}"
        break;
      fi
      git pull --rebase origin main
      sleep 3
    done
  fi
done
