---
title: "Installation - Jupyter Notebook"
description: "Using Imandra via a local Jupyter notebook"
kernel: imandra
slug: installation-jupyter
---

# Jupyter

You'll first need to run the [recommended, simple installation of Imandra](Installation%20-%20Simple.md).

After running the simple installer, you should see `imandra-jupyter-kernel` on your path. You'll now need to install the kernel as part of your local Jupyter setup in order to invoke this.

To install the Imandra and Imandra-reason kernels, run the following commands:

(Note: if you have a more intricate Jupyter environment setup or if you use `conda`, you'll need to adjust the commands accordingly to install things into the correct location).

```sh.copy
# install imandra and imandra kernels
jupyter kernelspec install /usr/local/var/imandra/_opam/share/jupyter/kernelspec/imandra
jupyter kernelspec install /usr/local/var/imandra/_opam/share/jupyter/kernelspec/imandra-reason

#install nbimandra notebook extensions as a python package (assumes this is in the same package target as jupyter itself)
pip install /usr/local/var/imandra/_opam/share/jupyter/nbextensions/nbimandra

#install nbimandra as an extension from the installed python package
jupyter nbextension install --py nbimandra
jupyter nbextension enable --py nbimandra
```

## Docker image

The notebook is also available as a docker image: `imandra/imandra-client-notebook`.

If you haven't authenticated yet and don't have an `~/.imandra` folder on your docker host, first authenticate using the regular `imandra/imandra-client` image:

```sh.copy
docker pull imandra/imandra-client:latest && \
  docker run -it --rm -v ${HOME}/.imandra:/root/.imandra -p 8000:8000 \
  imandra/imandra-client:latest
```

If everything succeeds you should be dropped into an `imandra-repl` session. Exit this with `C-d`.

Then to launch the notebook, mount your `~/.imandra` folder as a volume in the container. You may find it useful to mount the current directory in the container too so you can save notebooks you've edited:

```sh.copy
docker pull imandra/imandra-client-notebook:latest && \
  docker run -it --rm -v ${HOME}/.imandra:/home/jovyan/.imandra -p 8888:8888 \
  -v `pwd`:/home/jovyan/workdir \
  imandra/imandra-client-notebook
```
