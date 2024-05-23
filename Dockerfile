FROM ebrown/git:latest as built_git

FROM ebrown/python:3.11 as assembled
COPY --from=built_git /opt/git /opt/git
ENV PATH=/opt/git/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/git/lib:${LD_LIBRARY_PATH}
WORKDIR /app
ARG XGB_VERSION=2.0.3
ARG PY_NP_VERSION=1.26.4
ARG PY_SCIPY_VERSION=1.13.1
COPY ./xgboost-${XGB_VERSION}-py3-none-linux_x86_64.whl /tmp/xgboost-${XGB_VERSION}-py3-none-linux_x86_64.whl 
COPY ./numpy-${PY_NP_VERSION}-cp311-cp311-linux_x86_64.whl /tmp/numpy-${PY_NP_VERSION}-cp311-cp311-linux_x86_64.whl
COPY ./scipy-${PY_SCIPY_VERSION}-cp311-cp311-linux_x86_64.whl /tmp/scipy-${PY_SCIPY_VERSION}-cp311-cp311-linux_x86_64.whl
ENV LD_LIBRARY_PATH=/opt/python/py311/lib:${LD_LIBRARY_PATH}
ENV PATH=/opt/git/bin:/opt/python/py311/bin:${PATH}
RUN python3 -m virtualenv --symlinks --download /app/venv \
    && find ./ \
    		\( \
			\( -type d -a \( -name __pycache__ \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; 

RUN . /app/venv/bin/activate && \
        pip3 install --no-cache-dir --upgrade pip && \
        pip3 install --no-cache-dir --upgrade setuptools wheel && \
        pip3 install --no-cache-dir /tmp/numpy-${PY_NP_VERSION}-cp311-cp311-linux_x86_64.whl /tmp/scipy-${PY_SCIPY_VERSION}-cp311-cp311-linux_x86_64.whl /tmp/xgboost-${XGB_VERSION}-py3-none-linux_x86_64.whl /tmp/xgboost-${XGB_VERSION}-py3-none-linux_x86_64.whl && \
        pip3 install --no-cache-dir \
        torch torchvision torchaudio \
        opencv-contrib-python-headless \
        pillow \
		pillow-heif \
        heic2png \
        matplotlib \
        "aiohttp[speedups]" \
        jupyterlab>=4.1.8 \
        jupyterlab-lsp>=5.1.0 \
        jupyter-lsp>=2.2.3 \
        jupyter_server \
        "python-lsp-server[all]" \
        ipywidgets \
        jupyter_bokeh \
        jupyter-server-proxy \
        jupyter_http_over_ws \
        jupyter-collaboration \
        jupyterlab-git \
        ipyparallel \
        ipython \
        tqdm \
        "papermill[all]" \
        bokeh \
        seaborn \
        blake3 \
        psutil \
        mypy \
        "pandas[performance, excel, computation, plot, output_formatting, html, parquet, hdf5]" \
        tables \
        "polars[pandas, numpy, pyarrow, fsspec, connectorx, xlsx2csv, deltalake, timezone]" \
        polars-cli \
        fastexcel \
        openpyxl \
        apsw \
        pydot \
        plotly \
        pydot-ng \
        pydotplus \
        graphviz \
        lxml \
        beautifulsoup4 \
        scikit-learn-intelex \
        scikit-learn \
        scikit-image \
        sklearn-pandas \
        statsmodels \
        joblib \
        "black[jupyter]" \
        isort \
        yapf \
        "nbqa[toolchain]" \
        ruff \
        pipdeptree \
        bottleneck \ 
        pytest \
        hypothesis \
        zstandard \
        cloudpickle \
        connectorx \
        deltalake \
        gevent \
        requests \
        niquests \
        httpx \
        "fastapi[all]" \
#        "fastapi-cache2[redis]" \
        python-multipart \
        pydantic \
        "uvicorn[standard]" \
        pyyaml \
        xlsx2csv \
        cython \
        sqlalchemy && \find ./ \
                            \( \
                            \( -type d -a \( -name __pycache__ \) \) \
                            -o \
                            \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
                        \) -exec rm -rf '{}' +;           
RUN . /app/venv/bin/activate && pip3 install -U --no-cache-dir --no-dependencies qudida albumentations
FROM nvidia/cuda:12.1.1-cudnn8-runtime-rockylinux8 as prod
RUN yum install dnf-plugins-core -y && \
    dnf install epel-release -y && \
    /usr/bin/crb enable -y && \
    dnf --disablerepo=cuda update -y && \
    dnf install \
                unzip \
                curl \
                wget \
                libcurl-devel \
                gettext-devel \
                expat-devel \
                openssl-devel \
                openssh-server \
                openssh-clients \
                bzip2-devel bzip2 \
                xz-devel xz \
                libffi-devel \
                zlib-devel \
                ncurses ncurses-devel \
                readline-devel \
                libgfortran \
                uuid uuid-devel \
                tcl-devel tcl\
                tk-devel tk\
                sqlite-devel \
                graphviz \
                gdbm-devel gdbm \
                procps-ng \
                findutils -y && \
                dnf clean all;
ARG INSTALL_NODE_VERSION=20.13.1
RUN mkdir /opt/nodejs && \
    cd /opt/nodejs && \
    curl -L https://nodejs.org/dist/v${INSTALL_NODE_VERSION}/node-v${INSTALL_NODE_VERSION}-linux-x64.tar.xz | xzcat | tar -xf - && \
        PATH=/opt/nodejs/node-v${INSTALL_NODE_VERSION}-linux-x64/bin:${PATH} && \
        npm install -g npm && npm install -g yarn
RUN mkdir /opt/nvim && \
    cd /opt/nvim && \
    curl -L https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz | tar -zxf -
ENV PATH=/opt/nodejs/node-v${INSTALL_NODE_VERSION}-linux-x64/bin:/opt/nvim/nvim-linux64/bin:${PATH}
RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa \
    && ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa -b 521 \
    && ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
ENV PYDEVD_DISABLE_FILE_VALIDATION=1
WORKDIR /tmp
COPY installmkl.sh ./installmkl.sh
RUN chmod 700 ./installmkl.sh && ./installmkl.sh
COPY --from=assembled /opt/python/py311 /opt/python/py311
COPY --from=built_git /opt/git /opt/git
ENV LD_LIBRARY_PATH=/opt/python/py311/lib:${LD_LIBRARY_PATH}
ENV PATH=/opt/git/bin:/opt/python/py311/bin:${PATH}
ARG GIT_LFS_VERSION=3.5.1
RUN mkdir git-lfs && \
    cd git-lfs && \
    curl -L https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-amd64-v${GIT_LFS_VERSION}.tar.gz | tar -zxf - && \
    cd git-lfs-${GIT_LFS_VERSION} && \
    ./install.sh && \
    cd /tmp && \
    rm -rf /tmp/git-lfs
COPY --from=assembled /app/venv /app/venv/
ENV PATH /app/venv/bin:$PATH
WORKDIR /root
COPY ./root /root
COPY entrypoint.sh /usr/local/bin
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENV TERM=xterm-256color
ENV SHELL=/bin/bash
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-c", "jupyter lab"]
