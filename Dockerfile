# TODO: configure the below to switch to a multi-stage build:
# https://docs.docker.com/develop/develop-images/multistage-build/
FROM ubuntu:20.04

# Silent and unobtrusive, see man 7 debconf.
ENV DEBIAN_FRONTEND=noninteractive
# Dependencies for the R packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
libbz2-dev \
libcairo2-dev \
libcurl4-openssl-dev \
libfreetype6-dev \
libfribidi-dev \
libharfbuzz-dev \
libjpeg-dev \
libpng-dev \
libproj-dev \
libssl-dev \
libtiff5-dev \
libxml2-dev \
libxt-dev \
zlib1g-dev

# Compile dependencies for R and OpenBLAS.
RUN apt-get install -y --no-install-recommends build-essential \
cmake \
g++ \
gfortran \
make \
tk

# Install R.
RUN apt-get install -y --no-install-recommends software-properties-common dirmngr
RUN apt-get install -y --no-install-recommends gpg-agent
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository -y "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
RUN apt-get install -y --no-install-recommends r-base liblapack-dev

# Install OpenBLAS.
RUN apt-get install -y --no-install-recommends git
RUN git clone https://github.com/xianyi/OpenBLAS.git --branch v0.3.15 --depth=1
WORKDIR /OpenBLAS
# Uncomment the USE_THREAD = 0 rule in Makefile.
# Meant to compile OpenBLAS single-thread-only.
# Done to avoid https://github.com/bmbolstad/preprocessCore/issues/7
# ... and, generally, pthread_create issues with rma and fitPLM and...
RUN sed -i "/# USE_THREAD = 0/ s/^#//" Makefile.rule
# Have make use all processing units as reported from nproc.
RUN make -j $(nproc)
RUN make install

# Link OpenBLAS with R.
RUN ln -snf /opt/OpenBLAS/lib/libopenblas.so /usr/lib/x86_64-linux-gnu/libblas.so.3 && rm -rf /OpenBLAS/
# Use our OpenBLAS in -lblas from ld, not BLAS from liblapack-dev.
RUN ln -snf /opt/OpenBLAS/lib/libopenblas.so /usr/lib/libblas.so

# Install R packages in parallel.
RUN mkdir -p /usr/local/lib/R/etc/
RUN echo "options(Ncpus = $(nproc --all))" >> /usr/local/lib/R/etc/Rprofile.site

RUN R -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv')"
# Make sure BiocManager is already installed before renv::restore().
RUN R -e "if (!requireNamespace('BiocManager', quietly = TRUE)) install.packages('BiocManager')"

WORKDIR /project
COPY ./renv.lock .
# Install all dependencies based on the lock file.
# Timeout is for downloading packages; helps when connection is poor.
# https://rstudio.github.io/renv/reference/consent.html
# TODO: find a way to either build remotely, or speed the process up locally.
# TODO: Cut down on image size using https://rstudio.github.io/renv/articles/profiles.html
RUN R -e "options(renv.consent = TRUE); options(timeout = 300); renv::restore()"
# RUN R -e "BiocManager::install('preprocessCore', configure.args='--disable-threading', force = TRUE)"

# Set up locales so that R doesn't complain all the time.
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment &&\
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&\
echo "LANG=en_US.UTF-8" > /etc/locale.conf &&\
apt-get install -y --no-install-recommends locales &&\
locale-gen en_US.UTF-8

ENTRYPOINT [""]