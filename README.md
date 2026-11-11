# FrankenPHP Docker Hardened Images

[![Build][uQLTMg]][tk5Lec]

This project provides [Docker Hardened Images][bSpdG5] for [FrankenPHP][ZyMjUe].

The [build process][YmEcXD] for these FrankenPHP images uses the same declarative YAML definition format and applies the same best practices as other Docker Hardened Images. It statically compiles FrankenPHP from source on top of a Docker-hardened Alpine base.

The images are available as **runtime** and **dev** variants for all PHP versions that haven’t reached end of life yet.

See all [available tags and versions][eC6unD].

## Using the images

All examples in this guide use the public images hosted on GitHub’s container registry.

```shell
docker pull ghcr.io/kenshodigital/frankenphp:1-php8.5
```

### Exposing external ports

By default, FrankenPHP listens on port `8080` in these images. To expose this port to the host, use the `--publish` flag on `docker run`.

```shell
docker run \
  --publish 8080:8080 \
  ghcr.io/kenshodigital/frankenphp:1-php8.5
```

### Hosting a project

The default document root for FrankenPHP is `/srv/public` in these images. To host a PHP project, bind mount your application folder to `/srv` in the container.

```shell
docker run \
  --publish 8080:8080 \
  --volume ./app:/srv:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5
```

Alternatively, use a Dockerfile to build a new image that includes your project files.

```dockerfile
FROM ghcr.io/kenshodigital/frankenphp:1-php8.5
COPY ./app /srv
```

### Customizing configuration

#### Using environment variables

Use the following environment variables to customize the default server configuration.

- `SERVER_NAME` to configure the hostname, the port, or both.
- `SERVER_ROOT` to configure the document root.

```shell
docker run \
  --env SERVER_NAME=example.com \
  --env SERVER_ROOT=/app/public \
  --publish 80:80 \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --volume ./app:/app:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5
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

You can bind mount your Caddyfile into the container.

```shell
docker run \
  --publish 80:80 \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --volume ./Caddyfile:/usr/local/etc/frankenphp/Caddyfile:ro \
  --volume ./app:/app:ro \
  ghcr.io/kenshodigital/frankenphp:1-php8.5
```

Alternatively, build a new image that includes your custom configuration.

```dockerfile
FROM ghcr.io/kenshodigital/frankenphp:1-php8.5
COPY ./Caddyfile /usr/local/etc/frankenphp/Caddyfile
COPY ./app /app
```

Make sure to check out [FrankenPHP’s configuration docs][jMqJqq] as well.

### Running in read-only mode

To run these images in read-only mode, mount a Docker volume to every location where FrankenPHP writes data. Besides the locations your application needs to write to, FrankenPHP needs write access to `/home/nonroot` (the `nonroot` user’s home directory). It also needs a tmpfs mount for `/tmp`.

```shell
docker run \
  --publish 8080:8080 \
  --read-only \
  --tmpfs /tmp \
  --volume home:/home/nonroot \
  ghcr.io/kenshodigital/frankenphp:1-php8.5
```

### Using dev variants

Each runtime image comes with a corresponding dev variant including [Composer][Et32Qb], [Xdebug][uXy47d], and a shell.

#### Xdebug

Xdebug is enabled by default, so step-debugging should already work right out-of-the-box.

#### Composer

You can run Composer directly in the container.

```shell
docker exec -it mycontainer composer
```

Alternatively, open an interactive shell and run Composer from there.

```shell
docker exec -it mycontainer sh
```

## Customizing PHP

To customize PHP, you build your own FrankenPHP image. This repository shows how to [build your own Docker Hardened Images][NqgBb8] for FrankenPHP and how to [automate definition updates][r3kGc9] via GitHub Actions workflows. Just fork it and adapt it to your needs, or integrate its definitions and workflows into your existing projects.

### Default extensions

Runtime images include the following PHP extensions by default.

- brotli
- ctype
- curl
- dom
- fileinfo
- filter
- iconv
- intl
- libxml
- mbregex
- mbstring
- opcache
- openssl
- password-argon2
- pdo
- pdo_sqlite
- session
- simplexml
- sodium
- tokenizer
- xml
- zlib
- zstd

Dev variants also include the following PHP extensions. Composer, Xdebug, and [PHPUnit][yHAqJD] need them.

- phar
- xdebug
- xmlwriter
- zip

### Building your own

Except for Xdebug, all extensions are statically linked and compiled directly into the FrankenPHP binary via [StaticPHP][eBcxhu]. To add or remove extensions, adapt the list of extensions in the build command and rebuild the image from your customized definition file.

```yaml
runs: |
  spc doctor
  spc build:frankenphp \
  "brotli,ctype,curl,dom,fileinfo,filter,iconv,intl,libxml,mbregex,mbstring,opcache,openssl,password-argon2,pdo,pdo_sqlite,session,simplexml,sodium,tokenizer,xml,zlib,zstd" \
  # ...
```

Check out StaticPHP’s [list of extensions][b34cMM] to see what extensions are supported.

Before you build, sign in to a Docker account so you can pull base images and packages from dhi.io. Also pass a GitHub token as a `GIT_AUTH_TOKEN` secret to avoid rate limits when compiling from source.

Then build your custom image with a standard `docker buildx build` command.

```shell
docker buildx build . \
  --file image/1-php8.5-alpine3.24.yaml \
  --load \
  --provenance=1 \
  --sbom=generator=dhi.io/scout-sbom-indexer:1 \
  --secret id=GIT_AUTH_TOKEN,env=GITHUB_TOKEN \
  --tag frankenphp:1-php8.5
```

If you’re forking this repository and using the GitHub Actions workflows, you only have to pass the `DOCKER_ACTOR` and `DOCKER_TOKEN` secrets to the build workflow.

## Troubleshooting

### Debugging

Runtime images don’t come with a shell or debugging tools. Use Docker Debug to attach to a running container.

### Permissions

Docker Hardened Images run as the `nonroot` user by default. Make sure this user can access the files and directories it needs.

[uQLTMg]: https://github.com/kenshodigital/frankenphp/actions/workflows/build.yaml/badge.svg
[tk5Lec]: https://github.com/kenshodigital/frankenphp/actions/workflows/build.yaml
[bSpdG5]: https://www.docker.com/products/hardened-images/
[ZyMjUe]: https://frankenphp.dev
[YmEcXD]: https://docs.docker.com/dhi/how-to/build/
[eC6unD]: https://github.com/kenshodigital/frankenphp/pkgs/container/frankenphp/versions?filters%5Bversion_type%5D=tagged
[2nUp8C]: https://caddyserver.com
[jMqJqq]: https://frankenphp.dev/docs/config/
[Et32Qb]: https://getcomposer.org
[uXy47d]: https://xdebug.org
[yHAqJD]: https://phpunit.de
[eBcxhu]: https://static-php.dev
[b34cMM]: https://static-php.dev/en/guide/extensions.html
[NqgBb8]: https://github.com/kenshodigital/frankenphp/actions/workflows/build.yaml
[r3kGc9]: https://github.com/kenshodigital/frankenphp/actions/workflows/update.yaml
