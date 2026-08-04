FROM rocker/r-ver:4.5.1

RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c( \
  'plumber', \
  'readr', \
  'dplyr', \
  'ggplot2', \
  'recipes', \
  'parsnip', \
  'workflows', \
  'yardstick', \
  'ranger' \
), repos='https://cloud.r-project.org')"

WORKDIR /app

COPY model_api.R .
COPY run_api.R .
COPY data/water_potability.csv data/water_potability.csv

EXPOSE 8000

CMD ["Rscript", "run_api.R"]