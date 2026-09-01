ARG CUDA_VERSION=MUST_SET_CUDA_VERSION
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04

# Install dependencies
RUN apt-get update && apt-get install -y wget jq curl zstd

# Install Ollama using the provided script. OLLAMA_VERSION pins a specific
# release (eg: 0.23.2) so a rebuild can roll back a regression; "latest" or an
# empty value installs whatever is current. install.sh reads the version from
# the environment - see VER_PARAM in that script.
ARG OLLAMA_VERSION=latest
RUN PIN="$(printf '%s' "${OLLAMA_VERSION}" | sed 's/^latest$//; s/^v//')" \
    && echo "installing ollama ${PIN:-latest}" \
    && curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION="${PIN}" sh

# Download and install the latest Caddy
RUN LATEST_CADDY_URL=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | jq -r '.assets[] | select(.name | endswith("_linux_amd64.tar.gz")).browser_download_url') \
    && wget --no-check-certificate "$LATEST_CADDY_URL" -O caddy.tar.gz \
    && tar -xvf caddy.tar.gz -C /usr/bin caddy \
    && chown root:root /usr/bin/caddy \
    && chmod 755 /usr/bin/caddy

# Copy the Caddyfile and .env.local to the container
COPY Caddyfile /etc/caddy/Caddyfile
COPY .env /etc/caddy/.env.local

# Set the environment variable for the Ollama host
ENV OLLAMA_HOST=0.0.0.0

# Load environment variables from the .env.local file
RUN echo "source /etc/caddy/.env.local" >> /root/.bashrc

# Expose the port that Caddy will listen on
EXPOSE 80

# Copy a script to start both Ollama and Caddy
COPY start_services.sh /start_services.sh
RUN chmod +x /start_services.sh

# Set the entrypoint to the script
ENTRYPOINT ["/start_services.sh"]
