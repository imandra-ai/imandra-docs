---
title: "Installation - Manual Installation with opam"
description: "Getting set up with a local installation of Imandra"
kernel: imandra
slug: installation-manual-opam
---

# Manual Installation with opam

If you’re already familiar with the OCaml ecosystem and opam, you can use Imandra as a normal opam package, provided your switch is setup using ocaml 4.06.

The simplest way to install imandra in a custom switch is to install the `imandra-dist` metapackage, which includes the full Imandra distribution:

```sh.copy
opam switch create . ocaml-base-compiler.4.06.1
opam repo add imandra https://github.com/AestheticIntegration/opam-repository.git
opam update
opam depext imandra-dist
opam install imandra-dist
opam exec -- imandra_client -server 'imandra_network_client'
```

# Public packages

For more advanced installations, we include a list of the available packages in our [opam repository](https://github.com/AestheticIntegration/opam-repository):

- `imandra-auth-lib`: Library for authenticating to the Imandra Cloud
- `imandra-base`: Imandra base library, providing access to the Imandra protocol and syntax/surface types
- `imandra-base-bin`: Provides the `imandra-extract` and `imandra-codegen` binaries
- `imandra-client`: Imandra client library, providing entrypoints for the creation of custom Imandra clients
- `imandra-client-bin`: Provides the `imandra_client` binary
- `imandra-client-http-server`: Provides the `imandra_client_http_server` binary
- `imandra-cmd`: Provides the `imandra_cmd` binary (the Imandra launcher)
- `imandra-deps`: Metapackage used to synchronise dependency versions for all the `imandra-dist` packages
- `imandra-dist`: Metapackage used to install all the Imandra packages in one go
- `imandra-merlin`: Merlin extensions for imandra
- `imandra-network`: Provides the `imandra_network_client` binary, to be used as a server for `imandra_client`
- `imandra-prelude`: Imandra prelude as an OCaml Library
- `imandra-reason-parser`: Provides a ReasonML parser to Imandra
- `imandra-stdlib`: Imandra standard library of lemmas
- `imandra-tools`: Library providing extra tooling on top of Imandra's decomposition facilities
- `imandra-voronoi`: Library for visualizing Imandra Regions as a Voronoi diagram
- `imandra-vscode-server`: Provides the `imandra-vscode-server` binary, providing the backend for the VSCode based [Imandra IDE](https://marketplace.visualstudio.com/items?itemName=aestheticintegration.iml-vscode)
- `jupyter-imandra`: Jupyter notebook frontend for Imandra
