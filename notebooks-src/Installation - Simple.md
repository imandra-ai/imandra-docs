---
title: "Installation - Simple Installer"
description: "Getting set up with a local installation of Imandra"
kernel: imandra
slug: installation-simple
---

# Simple Installer

N.B. the following installer is supported natively on MacOS and Linux, on Windows you'll need to use [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

The simple installer will set up a new OCaml environment (using the `opam` installer), and then install Imandra. Execute the install script from a terminal:

```sh.copy
sh <(curl -s "https://storage.googleapis.com/imandra-installer/install.sh")
```

Or, if you have `wget` available instead of `curl`:

```sh.copy
sh <(wget -O - "https://storage.googleapis.com/imandra-installer/install.sh")
```

The installer will:
- Check for the presence of the opam package manager
- If not present it will install version 2 for the current user
- If present it will upgrade the current installation to version 2, if necessary
- Setup an OCaml 4.06.1 environment for Imandra
- Download, setup and install Imandra into its OCaml environment in `/usr/local/var/imandra/` (documentation for Imandra modules can be found in `_opam/doc/index.html`)
- Install system-level binaries for the Imandra repl and its utilities

The entire setup process will take a while, usually around 30 minutes; the process is almost entirely automatic but you might be prompted for input a couple of times, either to authenticate using `sudo` or for setting installation paths (we recommend using the default options).

After the installation is finished, you should have the following binaries installed in your installation path (`/usr/local/bin` unless you specified a custom one):
- `imandra`: this is the main Imandra entrypoint
- `imandra-repl`: this is the Imandra repl
- `imandra-http-server`: an http api around core Imandra features, with endpoints for evaluation, verification, instance generation etc. For more information, hit the `/spec` endpoint when the server is running for a full specification of endpoints and request/response formats for the version you have installed.
- `imandra-jupyter-kernel`: an Imandra kernel for Jupyter notebooks. See [Jupyter installation instructions](Installation%20-%20Jupyter.md) for further details.
- `imandra-extract`: a utility to transpile files from IML syntax into either OCaml or Reason syntax

The following tooling utilities will also be installed alongside the main binaries, they are used to provide [merlin](https://github.com/ocaml/merlin) integration for IDEs while writing or editing Imandra code:
- `imandra-merlin`
- `ocamlmerlin`
- `ocamlmerlin-imandra`
- `ocamlmerlin-imandra-reason`

Additionally, the `imandra-vscode-server` binary will be installed to provide full asynchronous proof-checking in the VSCode based [Imandra IDE](https://marketplace.visualstudio.com/items?itemName=aestheticintegration.iml-vscode). Please see the [Installation Page](Installation%20-%20VSCode.md) for details.
