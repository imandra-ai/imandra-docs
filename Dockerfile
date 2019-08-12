ARG FROM_IMAGE=imandra/imandra-client-notebook:latest
FROM $FROM_IMAGE as dev

USER root
RUN echo "c.NotebookApp.contents_manager_class = 'notedown.ImandraNotedownContentsManager'" >> /etc/jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.ip = '0.0.0.0'" >> /etc/jupyter/jupyter_notebook_config.py
USER $NB_USER
WORKDIR /home/jovyan/notebooks
