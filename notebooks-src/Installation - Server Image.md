---
title: "Installation - Server Image"
description: "Getting set up with a local installation of Imandra, with a local server"
kernel: imandra
slug: installation-server-image
---

# Prerequisites

You'll need to have pre-agreed access to `imandra-server` local installation with us for this to work, `imandra-server` is not available locally as standard.

You'll also need `docker` installed so the Imandra clients can run the `imandra-server` docker image.

# Installation

## Imandra client

First, run the normal local Imandra client installation process, following the [Simple installation instructions](Installation%20-%20Simple.md).

Next, tell your Imandra client to use a local docker image for `imandra-server`:

```shell
$ echo 'imandra/imandra-server' > ~/.imandra/server-image
```

Your local Imandra clients will now try to launch the server component locally inside a docker container. To switch back to using our cloud for `imandra-server`, remove the `~/.imandra/server-image` file.

## Imandra server

We provide access to a Docker registry containing the `imandra-server` image, but initially we may provide the image in the form of a `.tar.gz` archive while we're coordinating access.

Note that the `.tar.gz` archive only contains a single version of the server image and may stop working as your local Imandra clients auto-update.

### Loading the `.tar.gz` image into docker

The `.tar.gz` archive can be loaded into a local docker image as a substitute for it being fetched automatically from our registry (substituting `<server-version>` with the value in your tar archive filename):

```shell
$ docker load -i imandra-server_<server-version>.tar.gz
Loaded image: imandra/imandra-server:<server-version>
```

You can check which version of `imandra-server` your local Imandra installation expects by running:

```shell
$ imandra core repl -no-backend -v
Imandra v1.0.5
(c)Copyright Imandra Inc., 2014-2020. All rights reserved.

* Build commit ID <server-version>.
```

and observing the value of `<server-version>` that is output. If the version doesn't match, please contact us for an updated server `.tar.gz` archive for the newer version, or for image repository access.

### Configuring image fetch from our image repository

If we've configured your access to our image repository, you will need to login with `docker` on the authenticated dockerhub account:

```shell
$ docker login
```

Make sure you can pull an image from the repository without issue to confirm everything is setup:

```shell
$ docker pull imandra/imandra-server:latest
```

The Imandra client should now fetch new server images at the correct version automatically.

Now you should be able to use Imandra Core commands, such as `imandra core repl` and the Imandra VSCode extension without connecting to our reasoning cloud.
