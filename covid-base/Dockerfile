FROM r-base:4.0.3

MAINTAINER Michael Renda <mr787@njit.edu>


# Install OpenJDK 8 Runtime Environment

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  	file \
    git \
    libapparmor1 \
    libclang-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    procps \
    python-setuptools \
    sudo \
    wget \  
    libxml2-dev \
  	libcairo2-dev \
  	libsqlite-dev \
  	libmariadbd-dev \
  	libmariadbclient-dev \
  	libpq-dev \
  	libssh2-1-dev \
  	unixodbc-dev \
  	libsasl2-dev
  	

RUN sudo Rscript -e "install.packages('tidyr')"
RUN sudo Rscript -e "install.packages('dplyr')"
RUN sudo Rscript -e "install.packages('ggplot2')"
RUN sudo Rscript -e "install.packages('here')"
RUN sudo Rscript -e "install.packages('odbc')"
RUN sudo Rscript -e "install.packages('RMySQL')"
RUN sudo Rscript -e "install.packages('tidyverse')"
RUN sudo Rscript -e "install.packages('mapproj')"
RUN sudo Rscript -e "install.packages('scales')"
RUN sudo Rscript -e "install.packages('RCurl')"
