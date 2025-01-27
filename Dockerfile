# Copyright 2015-2017 Ivan Krizsan
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Elastalert Docker image running on Alpine Linux.
# Build image with: docker build -t ivankrizsan/elastalert:latest .

FROM python:3.6-alpine

LABEL maintainer="Jason Levine <levineja@mail.nih.gov>"

# Set this environment variable to True to set timezone on container start.
ENV SET_CONTAINER_TIMEZONE True
# Default container timezone as found under the directory /usr/share/zoneinfo/.
ENV CONTAINER_TIMEZONE America/New_York
# Elastalert version
ENV ELASTALERT_VERSION 0.2.4
# URL from which to download Elastalert.
ENV ELASTALERT_URL https://github.com/Yelp/elastalert/archive/v${ELASTALERT_VERSION}.zip
# Directory holding configuration for Elastalert and Supervisor.
ENV CONFIG_DIR /opt/config
# Elastalert rules directory.
ENV RULES_DIRECTORY /opt/rules
# Elastalert configuration file path in configuration directory.
ENV ELASTALERT_CONFIG ${CONFIG_DIR}/elastalert_config.yaml
# Directory to which Elastalert and Supervisor logs are written.
ENV LOG_DIR /opt/logs
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert
# Supervisor configuration file for Elastalert.
ENV ELASTALERT_SUPERVISOR_CONF ${CONFIG_DIR}/elastalert_supervisord.conf
# Alias, DNS or IP of Elasticsearch host to be queried by Elastalert. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_HOST elasticsearch
# Port on above Elasticsearch host. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_PORT 9200
# Use TLS to connect to Elasticsearch (True or False)
ENV ELASTICSEARCH_TLS False
# Verify TLS
ENV ELASTICSEARCH_TLS_VERIFY True
# ElastAlert writeback index
ENV ELASTALERT_INDEX elastalert

WORKDIR /opt

# Install software required for Elastalert and NTP for time synchronization.
RUN apk update && \
    apk upgrade && \
    apk add gcc libffi-dev musl-dev python3-dev openssl-dev tzdata libmagic && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Fix issue with versions of pip ES library 7+
# RUN sed -i 's/elasticsearch/elasticsearch<7/g' setup.py

# Install Elastalert.
RUN python setup.py install && \
    pip install -e . && \
    pip uninstall twilio --yes && \
    pip install twilio==6.0.0 && \

# Install Supervisor.
    easy_install supervisor && \

# Create directories. The /var/empty directory is used by openntpd.
    mkdir -p "${CONFIG_DIR}" && \
    mkdir -p "${RULES_DIRECTORY}" && \
    mkdir -p "${LOG_DIR}" && \
    mkdir -p /var/empty && \

# Clean up.
    apk del gcc libffi-dev musl-dev python-dev openssl-dev && \
    rm -rf /var/cache/apk/*

# Fix timezone issue (since Docker Swarm won't let us set clock capabilities)
RUN echo "UTC" > /etc/timezone

# Copy the script used to launch the Elastalert when a container is started.
COPY ./start-elastalert.sh /opt/
# Make the start-script executable.
RUN chmod +x /opt/start-elastalert.sh

# Define mount points.
VOLUME [ "${CONFIG_DIR}", "${RULES_DIRECTORY}", "${LOG_DIR}"]

# Launch Elastalert when a container is started.
CMD ["/opt/start-elastalert.sh"]
