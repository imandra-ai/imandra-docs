---
title: "Installation - Server Image"
description: "Getting set up with a local installation of Imandra, with a local server"
kernel: imandra
slug: installation-server-image
---

# Prerequisites

You'll need to have pre-agreed access to an `imandra-server` image repository with us for this to work, `imandra-server` is not available as standard.

You'll also need `docker` installed and authenticated to the `imandra-server` image repository. Make sure you're able to run a pull command from the repo without issue, e.g.:

```shell
$ docker login
$ docker pull imandra/imandra-server:latest
```

# Installation

First, run the normal installation process, following the [Simple installation instructions](Installation%20-%20Simple.md).

Next, tell the Imandra binaries where your `imandra-server` image is located:

```shell
$ echo 'imandra/imandra-server' > ~/.imandra/server-image
```

This configures the local Imandra clients to launch the server component locally inside a docker. Make sure you do not specify a `:version` tag at the end of the url - this is set automatically by the client so the correct server version is run against the currently installed version of the Imandra client.

Now you should be able to use Imandra Core commands, such as `imandra core repl` and the Imandra VSCode extension without connecting to our reasoning cloud.

## Server image tarball setup

We may provide you with a `.tar.gz` file containing the `imandra-server` image while we're setting up docker repo access. Note that this will only be a single version of the `server`, and will not work after `imandra-client` upgrades itself - you will need full docker repo access for ongoing updates to work correctly.

The `.tar.gz` file can be loaded into a local docker image as a substitute for `docker pull` from our registry:

```shell
$ docker load -i imandra-server_<server-version>.tar.gz
Loaded image: imandra/imandra-server:<server-version>
```

Docker will now be able to resolve the image when the Imandra clients attempt to start `imandra-server`.

If your `imandra-client` has already upgraded to a newer version automatically, you can install a specific version of the `imandra-client` using:

```shell
$ sh <(curl -s "https://storage.googleapis.com/imandra-installer/install-<installer-version>.sh")
```
NOTE: the version number for the installer is different from the version number for the server! Make sure you use the correct pair of installer+server image versions provided by us.

You can then launch a repl skipping auto-update using the `--skip-update` flag, which will keep you on the version you have a server image for:

```shell
$ imandra core repl --skip-update
```
