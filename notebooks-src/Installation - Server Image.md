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
docker pull url-of-imandra-docker-registry/imandra-server:latest
```

# Installation

First, run the normal installation process, following the [Simple installation instructions](Installation%20-%20Simple.md).

Next, tell the Imandra binaries where your `imandra-server` image is located:

```shell
echo 'url-of-imandra-docker-registry/imandra-server' > ~/.imandra/server-image
```

This configures the local Imandra client to launch the server component locally inside a docker. Make sure you do not specify a `:version` tag at the end of the url - this is set automatically by the client so the correct server version is run against the currently installed version of the Imandra client.

Now you should be able to use Imandra Core commands, such as `imandra core repl` and the Imandra VSCode extension without connecting to our reasoning cloud.
