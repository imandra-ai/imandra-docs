BRANCH_NAME ?= $(shell git branch --show-current)
COMMIT_SHA ?= $(shell git rev-parse HEAD)
IMANDRA_DOCS_BUILDER ?= eu.gcr.io/imandra-dev/imandra-docs-builder:latest
IMANDRA_TOKEN ?= $(shell cat ~/.keybase-repos/imandra-dev-keys/try-imandra-notebook/ci@aestheticintegration.com--imandra-token)
LAUNCH_URL ?= https://try.imandra.ai/launch/?next=/h/user-redirect/notebooks/
NOTEBOOKS_GCS_BUCKET ?= imandra-notebook-assets
SITE_PATH ?= imandra-docs

guard-%:
	@ if [ "${${*}}" = "" ]; then \
	    echo "Environment variable $* not set"; \
	    exit 1; \
	fi

docker-dev:
	docker build . \
    --pull \
    --target dev \
    --tag imandra-docs-dev:latest
	docker run -it --rm -p 8888:8888 \
    -v "$(shell pwd)/notebooks-src:/home/jovyan/notebooks" \
    -v ~/.imandra:/home/jovyan/.imandra \
    imandra-docs-dev:latest

_build:
	mkdir _build

docker-build-docs: _build
	@echo "$(IMANDRA_TOKEN)" > _build/login_token
	docker pull $(IMANDRA_DOCS_BUILDER)
	docker run --rm \
    -v `pwd`:/mnt/src \
    -v `pwd`/_build:/mnt/dst \
    -v `pwd`/_build/login_token:/home/jovyan/.imandra-dev/login_token \
    -e SITE_PATH=$(SITE_PATH) \
    -e LAUNCH_URL=$(LAUNCH_URL) \
    -e PARALLELISM="3" \
    -e IMANDRA_ENV="dev" \
    $(IMANDRA_DOCS_BUILDER)

serve-docs:
	 cd _build/sites && python3 -m http.server

upload-notebook-assets:
	gsutil mb -p imandra-prod gs://$(NOTEBOOKS_GCS_BUCKET)/ || true
	gsutil iam ch allUsers:objectViewer gs://$(NOTEBOOKS_GCS_BUCKET) || true
	gsutil -m cp -r notebook-assets/* gs://$(NOTEBOOKS_GCS_BUCKET)

deploy-docs:
	git clone git@github.com:AestheticIntegration/$(SITE_PATH) _docs-repo/$(SITE_PATH) || true
	cd _docs-repo/$(SITE_PATH) && git fetch && git checkout gh-pages && git reset --hard origin/gh-pages
	cd _docs-repo/$(SITE_PATH) && git rm -r index.html jekyll-resources notebooks static
	cp -r _build/sites/$(SITE_PATH)/* _docs-repo/$(SITE_PATH)/.
	cd _docs-repo/$(SITE_PATH) && git add -A && git commit -am "Docs update from $(COMMIT_SHA)" && git push origin gh-pages

deploy-notebooks:
	(cd _build/notebooks && find . -name '*.ipynb' -o -name "*.csv") | \
	  tar -czv -f "_build/notebooks-$(COMMIT_SHA).tar.gz" -C _build/notebooks --files-from -
	gsutil cp "_build/notebooks-$(COMMIT_SHA).tar.gz" "gs://$(NOTEBOOKS_GCS_BUCKET)/notebooks/notebooks-$(COMMIT_SHA).tar.gz"
	gsutil cp "_build/notebooks-$(COMMIT_SHA).tar.gz" "gs://$(NOTEBOOKS_GCS_BUCKET)/notebooks/notebooks-$(BRANCH_NAME).tar.gz"
	gsutil cp "_build/notebooks-$(COMMIT_SHA).tar.gz" "gs://$(NOTEBOOKS_GCS_BUCKET)/notebooks/notebooks-latest.tar.gz"

clean:
	rm -rf "_build" "_docs-repo"
	cd assets && make clean
