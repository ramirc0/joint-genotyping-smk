FROM ubuntu:22.04

# Use bash
SHELL ["/bin/bash", "-c"]

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV BCFTOOLS_PLUGINS=/usr/local/bcftools/plugins
ENV PATH=/root/.local/bin:${PATH}
RUN echo -e $PATH | tr ":" "\n"

# Install dependencies
RUN apt-get -y update && \
    apt-get -y install \
        openjdk-21-jdk \
        python3-dev \
        python3-full \
        build-essential \
        g++ \
        curl \
        git \
        wget \
        lz4 \
        unzip \
        cmake \
        gpg \
        pkg-config \
        autoconf \
        curl \
        jq \
        bc

# Install R gpg keys
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor -o /usr/share/keyrings/r-project.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | tee -a /etc/apt/sources.list.d/r-project.list

# Install more dependencies
RUN apt-get update && \
    apt-get install -y \
        r-base \
        libboost-all-dev \
        libgtest-dev \
        zlib1g-dev \
        libbz2-dev \
        liblzma-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        lbzip2 \
        libexpat1-dev \
        libncurses5-dev \
        libfreetype6-dev \
        libfontconfig1-dev

# Clean up
RUN apt-get -y clean && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt-get/lists/*

# Install python deps with uv
ENV VIRTUAL_ENV=/python-venv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN uv venv ${VIRTUAL_ENV}
ENV PATH=${VIRTUAL_ENV}/bin:${PATH}
# Install all optional dependencies for polars EXCEPT deltalake and apache iceberg
RUN uv pip install --no-cache-dir \
    macs3 \
    beautifulsoup4 \
    pandas \
    "polars[rt64,gpu,pandas,pyarrow,numpy,pydantic,excel,database,fsspec,async,cloudpickle,graph,plot,style,timezone]" \
    pysam \
    numpy \
    matplotlib \
    tqdm \
    multiqc

# Environment variables (compiler)
# NOTE: These must come after python installs, as they can interfere with certain packages (i.e. polars)
ENV CFLAGS="-O3 -march=x86-64-v4"
ENV CXXFLAGS="-O3 -march=x86-64-v4"

# Install SuiteSparse v7.6.0 which contains CHOLMOD5
RUN apt-get install -y libopenblas-dev libgmp-dev libmpfr-dev && \
    git clone --branch v7.6.0 https://github.com/DrTimothyAldenDavis/SuiteSparse.git /tmp/SuiteSparse && \
    cd /tmp/SuiteSparse && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    ldconfig && \
    rm -rf /tmp/SuiteSparse

# Install pigz (parallel gzip implementation)
RUN curl -sSLf https://zlib.net/pigz/pigz.tar.gz | tar xzf - && \
    cd /pigz && \
    make && \
    cp pigz unpigz /usr/local/bin
RUN rm -rf /pigz

# Install samtools stuff
RUN curl -s https://api.github.com/repos/samtools/htslib/releases/latest | \
    jq -r '.assets[] | select(.name | test("htslib-.*\\.tar\\.bz2")) | .browser_download_url' | \
    xargs curl -fsSL | tar xjf - && \
    cd /htslib-* && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install
RUN curl -s https://api.github.com/repos/samtools/samtools/releases/latest | \
    jq -r '.assets[] | select(.name | test("samtools-.*\\.tar\\.bz2")) | .browser_download_url' | \
    xargs curl -fsSL | tar xjf - && \
    cd /samtools-* && \
    ./configure && \
    make -j$(nproc) && \
    make install
RUN ln -sf /usr/include/suitesparse/cholmod.h /usr/include/cholmod.h && \
    ln -sf /usr/include/suitesparse/SuiteSparse_config.h /usr/include/SuiteSparse_config.h
RUN curl -s https://api.github.com/repos/samtools/bcftools/releases/latest | \
    jq -r '.assets[] | select(.name | test("bcftools-.*\\.tar\\.bz2")) | .browser_download_url' | \
    xargs curl -fsSL | tar xjf - && \
    cd /bcftools-* && \
    ./configure && \
    /bin/rm -f plugins/{score.{c,h},{munge,liftover,metal,blup}.c,pgs.{c,mk}} && \
    wget -P plugins http://raw.githubusercontent.com/freeseek/score/master/{score.{c,h},{munge,liftover,metal,blup}.c,pgs.{c,mk}} && \
    make CPPFLAGS="-I/usr/local/include/suitesparse" -j$(nproc) && \
    mkdir -p $BCFTOOLS_PLUGINS && \
    /bin/cp plugins/{munge,liftover,score,metal,pgs,blup}.so $BCFTOOLS_PLUGINS && \
    wget -P $BCFTOOLS_PLUGINS http://raw.githubusercontent.com/freeseek/score/master/assoc_plot.R && \
    chmod a+x $BCFTOOLS_PLUGINS/assoc_plot.R && \
    make install
RUN rm -rf /samtools-* /bcftools-* /htslib-*

# Install latest version of picard
RUN curl -s https://api.github.com/repos/broadinstitute/picard/releases/latest | \
    jq -r '.assets[] | select(.name == "picard.jar") | .browser_download_url' | \
    xargs curl -L -o /usr/bin/picard.jar

# Install DRAGEN mapper
RUN git clone https://github.com/Illumina/DRAGMAP.git /opt/DRAGMAP && \
    cd /opt/DRAGMAP && \
    sed -i 's/valStr\[20\]/valStr[21]/' thirdparty/dragen/src/common/hash_generation/hash_table.c && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/DRAGMAP

# Install VerifyBamID
RUN git clone https://github.com/Griffan/VerifyBamID.git /opt/VerifyBamID && \
    cd /opt/VerifyBamID && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make test && \
    cd .. && \
    cp bin/VerifyBamID /usr/local/bin && \
    rm -rf /opt/VerifyBamID

# Check everything was installed correctly
RUN which pigz && \
    which samtools && \
    which bcftools && \
    which java && \
    which dragen-os && \
    which VerifyBamID && \
    which python && \
    uv pip list

CMD ["/bin/bash"]
