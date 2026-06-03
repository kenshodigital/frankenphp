# FrankenPHP Hardened Images

[![Build][uQLTMg]][tk5Lec]

This project provides [Docker Hardened Images][bSpdG5] for [FrankenPHP][ZyMjUe].

The [build process][YmEcXD] for these images uses the same declarative YAML definition format and applies the same best practices as Docker Hardened Images. It installs pre-built upstream packages for FrankenPHP on top of a Docker hardened Alpine or Debian base.

[uQLTMg]: https://github.com/kenshodigital/frankenphp/actions/workflows/build.yaml/badge.svg
[tk5Lec]: https://github.com/kenshodigital/frankenphp/actions/workflows/build.yaml
[bSpdG5]: https://www.docker.com/products/hardened-images/
[ZyMjUe]: https://frankenphp.dev
[YmEcXD]: https://docs.docker.com/dhi/how-to/build/

## Using these images

All examples in this guide use the public images hosted on GitHub’s container registry.

```shell
docker pull ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

The images are available in Debian and Alpine variants and are updated daily for all PHP versions that haven’t reached end of life yet.

See all [available tags and versions][eC6unD].

[eC6unD]: https://github.com/kenshodigital/frankenphp/pkgs/container/frankenphp/versions?filters%5Bversion_type%5D=tagged

### Exposing external ports

By default, FrankenPHP listens on port `8080` in these images. To expose this port to the host, use the `--publish` flag on `docker run`.

```shell
docker run \
  --publish 8080:8080 \
  ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

### Hosting a project

The default document root for FrankenPHP is `/srv/public` in these images. To host a PHP project, bind mount your application folder to `/srv` in the container.

```shell
docker run \
  --publish 8080:8080 \
  --volume ./app:/srv:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

Alternatively, you can use a simple Dockerfile to build a new image including your project files.

```dockerfile
FROM ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
COPY ./app /srv
```

### Customizing configuration

#### Using environment variables

Use the following environment variables to customize the default server configuration.

- `SERVER_NAME` to configure the hostname and/or port.
- `SERVER_ROOT` to configure the document root.

```shell
docker run \
  --env SERVER_NAME=example.com \
  --env SERVER_ROOT=/app/public \
  --publish 80:80 \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --volume ./app:/app:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

#### Using a custom Caddyfile

Since FrankenPHP is based on [Caddy][2nUp8C], you can also customize configuration by providing your own Caddyfile.

```caddyfile
example.com {
	root /app/public
	encode zstd br gzip
	php_server
}
```

You can then either bind mount your Caddyfile into the container.

```shell
docker run \
  --publish 80:80 \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --volume ./Caddyfile:/etc/frankenphp/Caddyfile:ro \
  --volume ./app:/app:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

Or build a new image including your custom configuration directly.

```dockerfile
FROM ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
COPY ./Caddyfile /etc/frankenphp/Caddyfile
COPY ./app /app
```

Make sure to check out [FrankenPHP’s configuration docs][jMqJqq] as well.

[2nUp8C]: https://caddyserver.com
[jMqJqq]: https://frankenphp.dev/docs/config/

### Running in read-only mode

To run these images in read-only mode, mount a Docker volume to every location where FrankenPHP writes information. In addition to the locations your application needs to be writable, FrankenPHP requires write access to `/home/frankenphp` (the home directory for the `frankenphp` user), along with a tmpfs mount for the `/tmp` directory.

```shell
docker run \
  --publish 8080:8080 \
  --read-only \
  --tmpfs /tmp \
  --volume home:/home/frankenphp \
  ghcr.io/kenshodigital/frankenphp:1-php8.5-debian
```

### Customizing PHP

All runtime images include the following PHP extensions by default:

- calendar
- ctype
- curl
- dom
- exif
- fileinfo
- filter
- iconv
- libxml
- mbregex
- mbstring
- mysqli
- mysqlnd
- opcache
- openssl
- pcntl
- phar
- posix
- session
- shmop
- simplexml
- sockets
- sodium
- sqlite3
- tokenizer
- xhprof
- xml
- xmlreader
- xmlwriter
- zlib

Additional PHP extensions are available via package manager. Check out the StaticPHP packages for [Alpine][b34cMM] and [Debian][duTCWq] to see what’s supported.

[b34cMM]: https://pkg.henderkes.com/85/php-zts/packages?q=php-zts-&type=alpine
[duTCWq]: https://pkg.henderkes.com/85/php-zts/packages?q=php-zts-&type=debian

#### Using dev variants

Each runtime image comes with a corresponding dev variant including a package manager, [Composer][Et32Qb], [PIE][wZqJSj], and [Xdebug][uXy47d]. You can use these images in a multi-stage build to install additional PHP extensions and run CLI tasks.

```dockerfile
FROM ghcr.io/kenshodigital/frankenphp:1-php8.5-alpine-dev AS builder
RUN apk update
RUN apk add php-zts-gd
COPY ./app /srv
RUN composer install --no-interaction --no-dev --optimize-autoloader

FROM ghcr.io/kenshodigital/frankenphp:1-php8.5-alpine
COPY --from=builder /etc/php-zts/conf.d/20-gd.ini /etc/php-zts/conf.d/20-gd.ini
COPY --from=builder /usr/lib/php-zts/modules/gd-zts-85.so /usr/lib/php-zts/modules/gd-zts-85.so
COPY --from=builder /srv /srv
```

[Et32Qb]: https://getcomposer.org
[wZqJSj]: https://github.com/php/pie
[uXy47d]: https://xdebug.org

#### Building your own

Alternatively, you can build your own Docker Hardened Images directly by copying a definition file and adding additional packages from the StaticPHP repository.

```yaml
packages:
  - alpine-baselayout-data
  - busybox
  - ca-certificates-bundle
  - frankenphp
  - php-zts-bcmath
  - php-zts-embed
  - php-zts-gd
  - php-zts-pdo
  - php-zts-pdo_sqlite
  - tzdata
```

Then build your custom image.

```shell
docker buildx build . \
  --file image/1-php8.5-alpine3.23.yaml \
  --load \
  --provenance=1 \
  --sbom=generator=dhi.io/scout-sbom-indexer:1 \
  --tag frankenphp:1-php8.5-alpine-custom
```

##### Requirements

You need to be signed in to a Docker account to pull base images and packages from dhi.io to build your own Docker Hardened Images.

## Troubleshooting

### Debugging

Hardened images intended for runtime usually don’t contain a shell or debugging tools. Use Docker Debug to attach to these containers for debugging.

### Permissions

Image variants intended for runtime run as `frankenphp` user by default. Ensure that necessary files and directories are accessible to this user with the required permissions.
