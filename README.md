# Imandra-docs

## Developing a notebook locally

```
make docker-dev
```

## Markdown notebooks

We keep notebooks in markdown in the repo as it's easier to diff them for changes. Inside the Jupyter UI do `File > Save As` and save your file with `.md` file extension before committing it.

## Building the docs HTML

First make sure the `jekyll-resources` submodule is initialised:

```
git submodule update --init
```

The first run will take a while but after that notebook execution is cached which speeds things up a lot.

```
make docker-build-docs IMANDRA_TOKEN=$(cat ~/.imandra-dev/login_token)
```

Then serve the docs with:

```
make serve-docs
```

If your styles are messed up, you might have cached some bad style files - perhaps a build was run before the submodule was initialised. Clean out the asset cache:

```
cd assets
make clean
make all
cd ..
make docker-build-docs IMANDRA_TOKEN=$(cat ~/.imandra-dev/login_token)
```
