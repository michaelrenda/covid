FROM mr787/covid-base

MAINTAINER Michael Renda <mr787@njit.edu>

COPY covid-19.R .
COPY covid.sh .
RUN chmod 777 covid.sh

ENTRYPOINT ["./covid.sh"]
#ENTRYPOINT ["tail", "-f", "/dev/null"]