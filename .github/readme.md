<div align="center">
<a href="https://github.com/dockur/casa"><img src="https://raw.githubusercontent.com/dockur/casa/master/.github/logo.png" title="Logo" style="max-width:100%;" width="400" /></a>
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Package]][pkg_url]
[![Pulls]][hub_url]

</div></h1>

Docker container of [CasaOS](https://casaos.io/), an OS for self-hosting.

## Features ✨

- Does not need dedicated hardware or a virtual machine
- Provides access to the CasaOS web interface
- Supports installing and running CasaOS apps

## Usage  🐳

##### Docker Compose:

```yaml
services:
  casa:
    image: dockurr/casa
    container_name: casa
    ports:
      - 8080:8080
    volumes:
      - ./casa:/DATA
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
    stop_grace_period: 1m
```

##### Docker CLI:

```bash
docker run -it --rm --name casa -p 8080:8080 -v "${PWD:-.}/casa:/DATA" -v "/var/run/docker.sock:/var/run/docker.sock" --stop-timeout 60 docker.io/dockurr/casa
```

##### GitHub Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dockur/casa)

## Screenshot 📸

<div align="center">
<a href="https://github.com/dockur/casa"><img src="https://raw.githubusercontent.com/dockur/casa/master/.github/screen.png" title="Screenshot" style="max-width:100%;" width="256" /></a>
</div>

## FAQ 💬

### How do I change the storage location?

  To change the storage location, include the following bind mount in your compose file:

  ```yaml
  volumes:
    - ./casa:/DATA
  ```

  Replace the example path `./casa` with the desired storage folder or named volume.

### How do I run ZimaOS in a container?

  See [dockur/zima](https://github.com/dockur/zima) for a ZimaOS container.

### How do I run UmbrelOS in a container?

  See [dockur/umbrel](https://github.com/dockur/umbrel) for a UmbrelOS container.

 # Acknowledgements 🙏
 
Special thanks to [@worph](https://github.com/worph), this project would not exist without his invaluable work.

## Stars 🌟
[![Stargazers](https://raw.githubusercontent.com/star-stats/stars/refs/heads/data/charts/dockur-casa.svg)](https://github.com/dockur/casa/stargazers)

[build_url]: https://github.com/dockur/casa/
[hub_url]: https://hub.docker.com/r/dockurr/casa
[tag_url]: https://hub.docker.com/r/dockurr/casa/tags
[pkg_url]: https://github.com/dockur/casa/pkgs/container/casa

[Build]: https://github.com/dockur/casa/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/casa/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/casa.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/casa/latest?arch=amd64&sort=semver&color=066da5
[Package]:https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Fcasa%2Fcasa.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls

