---
title: "Installation - Simple Installer"
description: "Getting set up with a local installation of Imandra"
kernel: imandra
slug: installation-simple
---

# Simple Installer (macOS and Linux only)

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

When installing or updating new packages into the Imandra switch, it is crucial to make sure that the pinned packages required by the Imandra repl are consistent with the installed versions, here's the list of packages that _must_ be kept at the pinned version:

```
astring                 0.8.3
atd                     2.0.0
atdgen                  2.0.0
atdgen-runtime          2.0.0
base                    v0.11.1
base64                  2.2.0
biniou                  1.2.0
camlzip                 1.07
cmdliner                1.0.2
conf-gmp                1
conf-gmp-powm-sec       1
conf-m4                 1
conf-openssl            1
conf-perl               1
conf-pkg-config         1.1
conf-which              1
conf-zlib               1
conf-zmq                0.1
containers              2.3
cppo                    1.6.5
cpuid                   0.1.1
cryptokit               1.13
cstruct                 3.1.1
curly                   0.1.0
decoders                0.1.2
decoders-yojson         0.1.2
digestif                0.7.1
dune                    1.6.3
easy-format             1.3.1
eqaf                    0.2
imandra-base            1.0.4
imandra-client          1.0.4
imandra-merlin          0.2
imandra-prelude         1.0.4
imandra-reason-parser   0.1
imandra-stdlib          0.1
imandra-tools           2.0.0
ISO8601                 0.2.5
jupyter-imandra         0.0.1
jupyter-kernel          0.4
linenoise               1.2.0
lwt                     3.3.0
lwt-zmq                 2.1.0
lwt_ppx                 1.2.1
lwt_ssl                 1.1.2
menhir                  20171013
merlin                  3.2.2
merlin-extend           0.3
mirage-no-solo5         1
mirage-no-xen           1
nocrypto                0.5.4-1
num                     1.1
ocaml                   4.06.1
ocaml-base-compiler     4.06.1
ocaml-compiler-libs     v0.11.0
ocaml-migrate-parsetree 1.1.0
ocamlbuild              0.12.0
ocamlfind               1.8.0
ocamlgraph              1.8.8
ocb-stubblr             0.1.1
ocp-build               1.99.20-beta
ocp-indent              1.6.1
ocplib-endian           1.0
octavius                1.2.0
opam-depext             1.1.3
parsexp                 v0.11.0
ppx_tools_versioned     5.2.1
re                      1.8.0
result                  1.3
seq                     0.1
sexplib                 v0.11.0
sexplib0                v0.11.0
sha                     1.12
ssl                     0.5.5
stdint                  0.5.1
topkg                   0.9.1
tyxml                   4.3.0
uchar                   0.0.2
uuidm                   0.9.6
uutf                    1.0.2
yojson                  1.7.0
zarith                  1.7
zmq                     4.0-8
```
