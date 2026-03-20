# Ollama Behind Caddy Proxy

Caddy server to securely authenticate and proxy requests to a local Ollama instance, utilizing environment-based API key validation for enhanced security.



## Features

- **Secure API Access**: Uses Caddy to enforce API key authentication, allowing only requests with valid `Bearer` token/api-key.
- **Flexible Interaction**: Supports all endpoints to interact with the Ollama API.
- **Dockerized Setup**: Both Ollama and Caddy are containerized.
- **Latest Versions**: Utilizes the latest versions of Ollama and Caddy, ensuring the setup benefits from the most recent updates, security patches, and features. Docker image is configured to pull the latest versions automatically.
- **GPU Support**: Based on NVIDIA CUDA runtime for Ubuntu 22.04. The `setup` script auto-detects your host CUDA version and resolves the matching container image.



## Requirements

- Docker
- Docker Compose
- NVIDIA GPU with drivers installed (for GPU acceleration)



## Acknowledgements

This project is based on [ollama-bearer-auth](https://github.com/bartolli/ollama-bearer-auth) by [bartolli](https://github.com/bartolli). 

Significant modifications include:

- setup script
- dynamic CUDA version selection
- automatic bearer token generation
- auto pull/push to [Docker Hub](https://hub.docker.com/) account
- future: admin webapp for configuring api access

Note that bartolli has another project that provides an example of how to support multiple bearer tokens stored in a config file: [ollama-bearer-auth-caddy](https://github.com/bartolli/ollama-bearer-auth-caddy)



## Quick Start

Clone the repository:

```bash
git clone https://github.com/webstop/ollama-bearer-auth.git
cd ollama-bearer-auth
```

Run the setup script:

```bash
./setup
```

The script walks you through configuring the environment variables, building or pulling the Docker image, and optionally pushing it to Docker Hub. See [Setup Script Details](#setup-script-details) for the full flow.

Once setup is complete, start the services:

```bash
docker compose up -d
```



## Setup Script Details

The `setup` script is interactive and handles the entire build/configuration process. You can re-run it at any time — it reads existing values from `.env` as defaults, so you only need to change what is different.

The setup script can be ran again if you want to make changes.  Or if you just hit [enter] all the way through, it will just display the current config and drop through without performing any tasks.  If any config is missing from the `.env` then it will suggest a default value and prompt you to accept or change it.

### Phase 1: CUDA Version

The script detects your host CUDA version from `nvidia-smi` and resolves the latest patch release from Docker Hub (e.g., `13.1` resolves to `13.1.1`). You can accept the detected version or enter a different one — useful when building an image for a different machine.  The CUDA version will be written to **`CUDA_VERSION`** in the `.env`.

### Phase 2: Environment Variables

The script configures the `.env` file with:

- **`IMAGE_OWNER`** — Docker Hub username or organization. Defaults to your Docker Hub username if you are logged in.
- **`IMAGE_NAME`** — Docker image name. Defaults to `ollama-bearer-auth`.
- **`OLLAMA_API_KEY`** — Bearer token for API authentication. Auto-generated (format: `sk-ollama-<random>`) if not already set.
- **`EXPOSED_OLLAMA_PORT`** — Host port mapped to the container's port 8081. Defaults to `8081`.

### Phase 3: Docker Image

The script looks for the image `<IMAGE_OWNER>/<IMAGE_NAME>:<CUDA_VERSION>` and follows one of these paths:

- **Image found locally** — Skips ahead to Phase 4.
- **Image found on Docker Hub** — Offers to pull it. This is the fastest path if someone on your team has already built and pushed the image.
- **Image not found anywhere** — Offers to build it locally using `docker build`.

If you are **not logged in to Docker Hub**, the script can't check for or pull remote images. You can still build locally — you'll just skip the pull/push steps.  However, the script does ask you at this point whether you want to login and will facilitate that process.

### Phase 4: Docker Hub Push

After building or pulling:

- **Image was pulled** — Push is skipped (it's already on Docker Hub).
- **Image was built locally and you are logged in** — Offers to push the image to Docker Hub so others can pull it.
- **Not logged in** — Push is skipped with a message.

At each Docker Hub step, the script will offer to log you in if you aren't already.

Note that the size of the ollama install and CUDA support will be > 7GB.  So, it might be worth just building locally unless there is a good reason to store such large images on your dockerhub account.



## Sample ./setup run

The following is an example run where the `.env` already has values, dockerhub was already logged-in, and we built a new CUDA 12.4.1 version then pushed it.

```
$ ./setup

=========== setup: ollama-bearer-auth ============

        host OS CUDA version: 13.1

        The CUDA version of the image must match the host OS on the
        machine that will run the container. If you are building for a
        different machine, enter that machine's CUDA version instead.

        CUDA_VERSION [12.4.1]:

        docker image: webstop/ollama-bearer-auth:12.4.1  (<image_owner>/<image_name>:<cuda_version>)

        IMAGE_OWNER [webstop]:

        IMAGE_NAME [ollama-bearer-auth]:

        OLLAMA_API_KEY [sk-ollama-********************************]:

        EXPOSED_OLLAMA_PORT [8081]:

WARN    image 'webstop/ollama-bearer-auth:12.4.1' not found locally

        image 'webstop/ollama-bearer-auth:12.4.1' not found on Docker Hub

        Would you like to build it now? [y/N] y

        building image 'webstop/ollama-bearer-auth:12.4.1'...
        
[+] Building 125.7s (15/15) FINISHED                                                                                       docker:default
 => [internal] load build definition from Dockerfile                                                                                 0.1s
 => => transferring dockerfile: 1.29kB                                                                                               0.0s
 => [internal] load metadata for docker.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04                                                    1.2s
 => [auth] nvidia/cuda:pull token for registry-1.docker.io                                                                           0.0s
 => [internal] load .dockerignore                                                                                                    0.1s
 => => transferring context: 2B                                                                                                      0.0s
 => [1/9] FROM docker.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04@sha256:517da2300c184c9999ec203c2665244bdebd3578d12fcc7065e83667932  51.3s
 => => resolve docker.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04@sha256:517da2300c184c9999ec203c2665244bdebd3578d12fcc7065e836679326  0.2s
 => => sha256:517da2300c184c9999ec203c2665244bdebd3578d12fcc7065e83667932643d9 743B / 743B                                           0.0s
 => => sha256:cff3a0d82d2c2b47bab252d67fa9b34a20ef4c50781d98501b5c7367ea9afd10 2.21kB / 2.21kB                                       0.0s
 => => sha256:a112cf8dd3c22518fd3e81de177b6fadf34a4328d52c1b5ad7e856a6865d113d 13.94kB / 13.94kB                                     0.0s
 => => sha256:3c645031de2917ade93ec54b118d5d3e45de72ef580b8f419a8cdc41e01d042c 29.53MB / 29.53MB                                     2.0s
 => => sha256:0d6448aff88945ea46a37cfe4330bdb0ada228268b80da6258a0fec63086f404 4.62MB / 4.62MB                                       0.8s
 => => sha256:0a7674e3e8fe69dcd7f1424fa29aa033b32c42269aab46cbe9818f8dd7154754 57.59MB / 57.59MB                                     3.4s
 => => sha256:b71b637b97c5efb435b9965058ad414f07afa99d320cf05e89f10441ec1becf4 185B / 185B                                           1.0s
 => => sha256:56dc8550293751a1604e97ac949cfae82ba20cb2a28e034737bafd7382559609 6.89kB / 6.89kB                                       1.2s
 => => sha256:ec6d5f6c9ed94d2ee2eeaf048d90242af638325f57696909f1737b3158d838cf 1.37GB / 1.37GB                                      29.5s
 => => extracting sha256:3c645031de2917ade93ec54b118d5d3e45de72ef580b8f419a8cdc41e01d042c                                            0.9s
 => => sha256:47b8539d532f561cac6d7fb8ee2f46c902b66e4a60b103d19701829742a0d11e 64.05kB / 64.05kB                                     2.2s
 => => sha256:fd9cc1ad8dee47ca559003714d462f4eb79cb6315a2708927c240b84d022b55f 1.68kB / 1.68kB                                       2.4s
 => => sha256:83525caeeb359731f869f1ee87a32acdfdd5efb8af4cab06d8f4fdcf1f317daa 1.52kB / 1.52kB                                       2.7s
 => => extracting sha256:0d6448aff88945ea46a37cfe4330bdb0ada228268b80da6258a0fec63086f404                                            0.1s
 => => extracting sha256:0a7674e3e8fe69dcd7f1424fa29aa033b32c42269aab46cbe9818f8dd7154754                                            1.1s
 => => extracting sha256:b71b637b97c5efb435b9965058ad414f07afa99d320cf05e89f10441ec1becf4                                            0.0s
 => => extracting sha256:56dc8550293751a1604e97ac949cfae82ba20cb2a28e034737bafd7382559609                                            0.0s
 => => extracting sha256:ec6d5f6c9ed94d2ee2eeaf048d90242af638325f57696909f1737b3158d838cf                                           19.5s
 => => extracting sha256:47b8539d532f561cac6d7fb8ee2f46c902b66e4a60b103d19701829742a0d11e                                            0.0s
 => => extracting sha256:fd9cc1ad8dee47ca559003714d462f4eb79cb6315a2708927c240b84d022b55f                                            0.0s
 => => extracting sha256:83525caeeb359731f869f1ee87a32acdfdd5efb8af4cab06d8f4fdcf1f317daa                                            0.0s
 => [internal] load build context                                                                                                    0.1s
 => => transferring context: 92B                                                                                                     0.0s
 => [2/9] RUN apt-get update && apt-get install -y wget jq curl zstd                                                                 9.9s
 => [3/9] RUN curl -fsSL https://ollama.com/install.sh | sh                                                                         50.3s
 => [4/9] RUN LATEST_CADDY_URL=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | jq -r '.assets[] | se  2.8s
 => [5/9] COPY Caddyfile /etc/caddy/Caddyfile                                                                                        0.4s
 => [6/9] COPY .env /etc/caddy/.env.local                                                                                            0.3s
 => [7/9] RUN echo "source /etc/caddy/.env.local" >> /root/.bashrc                                                                   0.6s
 => [8/9] COPY start_services.sh /start_services.sh                                                                                  0.4s
 => [9/9] RUN chmod +x /start_services.sh                                                                                            0.6s
 => exporting to image                                                                                                               7.1s
 => => exporting layers                                                                                                              7.0s
 => => writing image sha256:56f1bc7946ce5e0665006875b6816114b5132bc874f55ed5544b08f497c5d54c                                         0.0s
 => => naming to docker.io/webstop/ollama-bearer-auth:12.4.1                                                                         0.0s
        build successful

        Would you like to push 'webstop/ollama-bearer-auth:12.4.1' to Docker Hub? [y/N] y

        pushing 'webstop/ollama-bearer-auth:12.4.1' to Docker Hub...

The push refers to repository [docker.io/webstop/ollama-bearer-auth]
2d99ae7a16ac: Layer already exists
950eb92bfa5a: Layer already exists
1e652496d6fa: Pushed
a2215aa4f2ba: Pushed
3e1bae70a79f: Pushed
89cd6f5825fe: Pushed
1b454885614d: Pushed
15d8cfcb6691: Pushed
2b4acda8678c: Mounted from nvidia/cuda
89fd878224a0: Mounted from nvidia/cuda
1b30dd39de27: Mounted from nvidia/cuda
1ffbbe19418f: Mounted from nvidia/cuda
809d3bb9c80f: Mounted from nvidia/cuda
46d54736d31f: Mounted from nvidia/cuda
efe2b79b53de: Mounted from nvidia/cuda
47654eeadbc5: Mounted from nvidia/cuda
e0a9f5911802: Mounted from nvidia/cuda
12.4.1: digest: sha256:b77da2303b714f96dc5e22536e5b4fe46a9ea33a179b10e0986d3b3b88d3e070 size: 3881

        push successful
```

The `.env` file at beginning and end (made no changes) of running the script looks like:

```bash
OLLAMA_API_KEY=sk-ollama-********************************
EXPOSED_OLLAMA_PORT=8081
IMAGE_OWNER=webstop
IMAGE_NAME=ollama-bearer-auth
CUDA_VERSION=12.4.1
```



## Running the Image

### With Docker Compose (recommended)

If you cloned the repo and ran `./setup`, the `.env` file provides all the configuration that `docker-compose.yml` needs:

```bash
docker compose up -d
```

To stop:

```bash
docker compose down
```

### With Docker Run (standalone)

If the image has been pushed to Docker Hub, you can run it directly on any machine without cloning the repo:

```bash
docker run -d -p 8081:8081 -e OLLAMA_API_KEY=your_api_key <IMAGE_OWNER>/<IMAGE_NAME>:<CUDA_VERSION>
```

For example:

```bash
docker run -d -p 8081:8081 -e OLLAMA_API_KEY=your_api_key webstop/ollama-bearer-auth:13.1.1
```

Replace `your_api_key` with the actual API key from your `.env` file.

**Mount existing Ollama models from your host machine (optional):**

```bash
docker run -d -p 8081:8081 -e OLLAMA_API_KEY=your_api_key -v ~/.ollama:/root/.ollama webstop/ollama-bearer-auth:13.1.1
```

**Mount a volume to persist Ollama models outside the container:**

```bash
docker run -d -p 8081:8081 -e OLLAMA_API_KEY=your_api_key -v ollama_docker_volume:/root/.ollama webstop/ollama-bearer-auth:13.1.1
```

**Note for Windows Users:** On Linux and macOS, the manifests use colons (`:`) in filenames, which are not permitted on Windows filesystems. You may encounter issues mounting the host `~/.ollama` directory on Windows. See [Issue 2032](https://github.com/ollama/ollama/issues/2032) and [Issue 2832 Comment](https://github.com/ollama/ollama/issues/2832#issuecomment-1994889376).



## Caddyfile Configuration

The `Caddyfile` controls Caddy's reverse proxy behavior. The default configuration authenticates requests using the `OLLAMA_API_KEY` environment variable and proxies them to the local Ollama instance. Edit the `Caddyfile` directly if you need to customize routing, TLS, or other Caddy settings.



## Environment Variables

All variables are stored in the `.env` file and configured by the `setup` script.

| Variable | Description | Default |
|---|---|---|
| `CUDA_VERSION` | CUDA runtime version used as the image tag | Auto-detected from host |
| `IMAGE_OWNER` | Docker Hub account or organization | Docker Hub username if logged in |
| `IMAGE_NAME` | Docker image name | `ollama-bearer-auth` |
| `OLLAMA_API_KEY` | Bearer token for API authentication | Auto-generated `sk-ollama-*` |
| `EXPOSED_OLLAMA_PORT` | Host port mapped to container port 8081 | `8081` |



## Testing API Key Authentication

### Test with incorrect API Key

Test the server's response with an incorrect API key. This should return a `401 Unauthorized` status:

```bash
curl -i http://localhost:8081 -H "Authorization: Bearer wrong_api_key"
```

### Test with correct API Key

Use the `OLLAMA_API_KEY` value from your `.env` file. This should return a `200 OK` status:

```bash
curl -i http://localhost:8081 -H "Authorization: Bearer your_api_key"
```

Replace `your_api_key` with the actual `OLLAMA_API_KEY` from your `.env` file. If you changed `EXPOSED_OLLAMA_PORT`, replace `8081` with your configured port.

---

Note: This project is a modified and improved clone of [ollama-auth](https://github.com/g1ibby/ollama-auth), which originally used a basic auth configuration and a fixed version of Caddy. This enhanced version leverages environment-based API key validation for enhanced security and automatically pulls the latest versions of both Ollama and Caddy.
