<div align="center">
<a href="https://github.com/dockur/casaos"><img src="https://raw.githubusercontent.com/dockur/casa/master/.github/logo.png" title="Logo" style="max-width:100%;" width="400" /></a>
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Package]][pkg_url]
[![Pulls]][hub_url]

</div></h1>

Docker container of [CasaOS](https://casaos.zimaspace.com/) (an OS for self-hosting).

## Features ✨

* Does not need dedicated hardware or a virtual machine!

## Usage  🐳

Via Docker Compose:

```yaml
services:
  casaos:
    image: dockurr/casa
    container_name: casa
    ports:
      - 8080:8080
    volumes:
      - "/home/example:/DATA"
      - "/var/run/docker.sock:/var/run/docker.sock"
    stop_grace_period: 1m
```

Via Docker CLI:

```bash
docker run -it --rm -p 8080:8080 -v /home/example:/DATA -v /var/run/docker.sock:/var/run/docker.sock --stop-timeout 60 dockurr/casa
```

## Screenshot 📸

<div align="center">
<a href="https://github.com/dockur/casa"><img src="https://raw.githubusercontent.com/dockur/casaos/master/.github/screen.png" title="Screenshot" style="max-width:100%;" width="256" /></a>
</div>

## FAQ 💬

### How do I change the storage location?

  To change the storage location, include the following bind mount in your compose file:

  ```yaml
  volumes:
    - /home/example:/DATA
  ```

  Replace the example path `/home/example` with the desired storage folder.

## Stars 🌟
[![Stars](https://starchart.cc/dockur/casa.svg?variant=adaptive)](https://starchart.cc/dockur/casa)

[build_url]: https://github.com/dockur/casa/
[hub_url]: https://hub.docker.com/r/dockurr/casa
[tag_url]: https://hub.docker.com/r/dockurr/casa/tags
[pkg_url]: https://github.com/dockur/casaos/pkgs/container/casa

[Build]: https://github.com/dockur/casa/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/casa/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/casa.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/casa/latest?arch=amd64&sort=semver&color=066da5
[Package]:https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Fcasa%2Fcasa.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls

