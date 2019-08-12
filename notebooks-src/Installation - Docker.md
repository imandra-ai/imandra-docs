---
title: "Installation - Docker"
description: "Getting set up with Imandra using Docker"
kernel: imandra
slug: installation-docker
---

# Docker Installation

If you want to run Imandra in a container, you can use our official Docker image (You first need to have [Docker](https://www.docker.com/get-started) installed in your machine)

From a terminal execute:

```sh.copy
docker pull imandra/imandra-client:latest && \
  docker run -it --rm -v ${HOME}/.imandra:/root/.imandra \
  imandra/imandra-client:latest
```

The above container contains a stripped down version of the tools provided through the local installer, installed in a `debian:9` base image, and crucially, doesn't include a functional opam environment in order to minimize the image size.

If you need a Docker image that includes a functional opam switch in order to extend the set of libraries available from Imandra, you can use the `imandra/imandra-client-switch` image instead. The available tags are `ubuntu`, `debian` and `latest`, with `latest` aliasing `debian`.

The command to run Imandra using one of those images is:

```sh.copy
docker pull imandra/imandra-client-switch:latest && \
  docker run -it --rm -v ${HOME}/.imandra:/home/opam/.imandra \
  imandra/imandra-client-switch:latest
```

In order to ensure that the set of runtime dependencies for Imandra is correctly installed, for the moment we only officially support using one of those images as a base for your custom Docker images.
