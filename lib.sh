# Shared helpers for the ollama-bearer-auth scripts.
# Sourced by ./setup and ./check_for_updates - not executable on its own.

RED='\033[0;31m'
ORANGE='\033[38;5;214m'
GREY='\033[38;5;243m'
GREEN='\033[38;5;46m'
BLACK_ON_BLUE='\033[30;44m'
RESET='\033[0m'

# Variant of the nvidia/cuda base image the Dockerfile builds FROM.
# Must match the FROM line in the Dockerfile.
CUDA_IMAGE_SUFFIX='-runtime-ubuntu22.04'

# Aborts unless every command named is available on PATH. All missing commands
# are reported at once rather than one failed run at a time.
# Usage: require_commands curl jq docker
require_commands() {
  local cmd
  local missing=()

  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  [ ${#missing[@]} -eq 0 ] && return 0

  echo -e "${RED}ERROR:${RESET}  missing required command(s): ${missing[*]}" >&2
  echo >&2
  echo -e "${GREY}        Install them with your package manager and run this script again -" >&2
  echo -e "        the package name does not always match the command name.${RESET}" >&2
  echo >&2
  exit 1
}

# Examples:
#   current_value="$(get_env_var OLLAMA_API_KEY)"
#   current_value="$(get_env_var DATABASE_URL .env)"

get_env_var() {
  local var_name="$1"
  local env_file="${2:-.env}"
  sed -n "s/^${var_name}=\(.*\)$/\1/p" "$env_file" 2>/dev/null | tr -d '"'\'''
}


# Usage:
#   ensure_env_var VAR_NAME [--prompt <text>] [--value <val>] [--env-file <file>]
#
# Examples:
#   ensure_env_var OLLAMA_API_KEY --value "sk-ollama-$(openssl rand -hex 16)"
#   ensure_env_var OLLAMA_API_KEY --prompt "Enter your Ollama API key"
#   ensure_env_var OLLAMA_API_KEY --prompt "Enter your Ollama API key" --value "sk-ollama-$(openssl rand -hex 16)"

ensure_env_var() {
  local var_name="$1"
  local prompt_text=""
  local supplied_value=""
  local env_file=".env"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt)   prompt_text="$2";    shift 2 ;;
      --value)    supplied_value="$2"; shift 2 ;;
      --env-file) env_file="$2";       shift 2 ;;
      *) echo "Unknown arg: $1" >&2; return 1 ;;
    esac
  done

  # Read current value from env file
  local current_value
  current_value="$(sed -n "s/^${var_name}=\(.*\)$/\1/p" "$env_file" 2>/dev/null | tr -d '"'\''')"

  if [ -n "$current_value" ]; then
    local new_value
    read -r -p "        ${var_name} [${current_value}]: " new_value
    echo
    if [ -z "$new_value" ]; then
      new_value="$current_value"
    fi
    if [ "$new_value" != "$current_value" ]; then
      sed -i "s|^${var_name}=.*|${var_name}=${new_value}|" "$env_file"
    fi
    export "${var_name}=${new_value}"
    return 0
  fi

  echo -e "${GREEN}NOTE:${RESET}   ${var_name} has not been set in ${env_file} yet."
  echo

  local new_value=""

  if [ -n "$prompt_text" ]; then
    read -r -p "        ${prompt_text}: " new_value
    [ -z "$new_value" ] && new_value="$supplied_value"  # fall back to --value
    echo
  elif [ -n "$supplied_value" ]; then
    new_value="$supplied_value"
  else
    echo -e "${RED}ERROR:${RESET}  No --value or --prompt provided for ${var_name}." >&2
    return 1
  fi

  if [ -z "$new_value" ]; then
    echo -e "${RED}ERROR:${RESET}  Could not determine a value for ${var_name}." >&2
    return 1
  fi

  if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
    sed -i "s|^${var_name}=.*|${var_name}=${new_value}|" "$env_file"
  else
    echo "${var_name}=${new_value}" >> "$env_file"
  fi

  export "${var_name}=${new_value}"

  echo "        ${var_name}: ${new_value}"
  echo
}


# Examples:
#   if ! prompt_yn "Would you like to build it now?"; then ...
prompt_yn() {
  local msg="$1"
  while true; do
    read -rp "        $(echo -e "${msg} [y/N] ")" yn
    case "${yn,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "        Please answer y or n." ;;
    esac
  done
}


# Ensures the user is logged in to Docker Hub.
# Returns 0 if logged in (or just logged in successfully), 1 otherwise.
ensure_docker_login() {
  if docker info 2>/dev/null | grep -q "Username:"; then
    return 0
  fi
  echo -e "${ORANGE}WARN${RESET}    You are not logged in to Docker Hub."
  echo
  read -rp "        Docker Hub username: " DH_USER
  read -rsp "        Docker Hub password/token: " DH_PASS
  echo
  echo "        Logging in to Docker Hub as '${DH_USER}'..."
  if echo "${DH_PASS}" | docker login --username "${DH_USER}" --password-stdin; then
    echo "        Logged in as '${DH_USER}'."
    echo
    return 0
  else
    echo
    echo -e "${RED}ERROR:${RESET}  Docker Hub login failed."
    return 1
  fi
}


# Prints the host's CUDA version (eg: "13.3"). Prints nothing if it cannot be
# determined (no GPU, no driver, nvidia-smi missing).
# nvidia-smi's XML output is parsed rather than the header table, whose label
# changed from "CUDA Version" to "CUDA UMD Version" in driver 610.x. The
# cuda_version tag is deprecated for removal in CUDA 14.0, so prefer the newer
# cuda_umd_version and fall back to the legacy tag for older drivers.
host_cuda_version() {
  local xml ver tag
  xml="$(nvidia-smi -q -x 2>/dev/null)" || return
  for tag in cuda_umd_version cuda_version; do
    ver="$(printf '%s\n' "$xml" | sed -n "s|.*<${tag}>\([0-9]\+\.[0-9]\+\).*|\1|p" | head -1)"
    [ -n "$ver" ] && { echo "$ver"; return; }
  done
}


# Lists the published CUDA patch releases for a given major.minor, oldest
# first. Usage: list_cuda_patch_versions 13.3   →  prints "13.3.0" "13.3.1"
# Prints nothing if the query fails.
list_cuda_patch_versions() {
  local major_minor="$1"
  curl -sf "https://hub.docker.com/v2/repositories/nvidia/cuda/tags?name=${major_minor}&page_size=100" \
    | jq -r '.results[].name' \
    | grep -E "^${major_minor}\.[0-9]+${CUDA_IMAGE_SUFFIX}$" \
    | sort -V \
    | sed "s/${CUDA_IMAGE_SUFFIX}//"
}


# Queries Docker Hub for the latest patch release of a given CUDA major.minor.
# Usage: resolve_cuda_patch_version 13.1   →  prints "13.1.1"
# Falls back to "${1}.0" if the query fails.
resolve_cuda_patch_version() {
  local major_minor="$1"
  local resolved
  resolved="$(list_cuda_patch_versions "$major_minor" | tail -1)" 2>/dev/null
  [ -z "$resolved" ] && resolved="${major_minor}.0"
  echo "$resolved"
}


# Checks whether the CUDA base image the Dockerfile needs exists on Docker Hub.
# Returns 0 if it exists, 1 if Docker Hub reports it does not, and 2 if the
# check could not be made (offline, rate limited) so the caller may proceed.
# Usage: cuda_base_image_exists 13.3.1
cuda_base_image_exists() {
  curl -sf "https://hub.docker.com/v2/repositories/nvidia/cuda/tags/${1}${CUDA_IMAGE_SUFFIX}" >/dev/null
  case $? in
    0)  return 0 ;;
    22) return 1 ;;  # HTTP error - the tag is not published
    *)  return 2 ;;  # could not reach Docker Hub
  esac
}


# Aborts before a build if the CUDA base image is known to be missing. A check
# that could not be made is only a warning - docker build will report it.
assert_cuda_base_image() {
  cuda_base_image_exists "$CUDA_VERSION"
  case $? in
    1)
      echo -e "${RED}ERROR:${RESET}  base image 'nvidia/cuda:${CUDA_VERSION}${CUDA_IMAGE_SUFFIX}' is not published"
      echo
      local major_minor available
      major_minor="$(echo "$CUDA_VERSION" | cut -d. -f1,2)"
      available="$(list_cuda_patch_versions "$major_minor" | paste -sd' ')"
      if [ -n "$available" ]; then
        echo "        published ${major_minor} releases: ${available}"
      else
        echo "        no ${major_minor} releases are published for ${CUDA_IMAGE_SUFFIX#-}"
      fi
      echo
      echo -e "${GREY}        Set CUDA_VERSION in .env to a published tag - see"
      echo -e "        https://hub.docker.com/r/nvidia/cuda/tags${RESET}"
      echo
      exit 1
      ;;
    2)
      echo -e "${ORANGE}WARN${RESET}    could not reach Docker Hub to verify the CUDA base image"
      echo "        continuing - the build will fail if the tag does not exist"
      echo
      ;;
  esac
}


# Prints the ollama version baked into a docker image (eg: "0.18.2").
# Prints nothing if the version cannot be determined.
# Usage: image_ollama_version webstop/ollama-bearer-auth:12.4.1
image_ollama_version() {
  # 'ollama --version' reports "ollama version is X" when a server is running
  # and "client version is X" when one is not - match the version either way.
  docker run --rm --entrypoint ollama "$1" --version 2>&1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1
}


# Prints the latest ollama release version from GitHub (eg: "0.33.2").
# Prints nothing if the lookup fails.
latest_ollama_version() {
  curl -sf https://api.github.com/repos/ollama/ollama/releases/latest \
    | jq -r '.tag_name // empty' \
    | sed 's/^v//'
}


# Returns 0 if $1 is a strictly newer version than $2.
# Usage: if version_gt "0.33.2" "0.18.2"; then ...
version_gt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}



# Prints the ollama version pinned in .env, or nothing when the build should
# track the newest release. An unset value and "latest" both mean "not pinned".
# Usage: pin="$(pinned_ollama_version)"
pinned_ollama_version() {
  local pin
  pin="$(get_env_var OLLAMA_VERSION)"
  pin="${pin#v}"
  [ "$pin" = "latest" ] && pin=""
  echo "$pin"
}


# Returns 0 if the given ollama release is published, 1 if GitHub reports it is
# not, and 2 if the check could not be made (offline, rate limited).
# Usage: ollama_version_exists 0.23.2
ollama_version_exists() {
  curl -sf -o /dev/null "https://api.github.com/repos/ollama/ollama/releases/tags/v${1#v}"
  case $? in
    0)  return 0 ;;
    22) return 1 ;;  # HTTP error - no such release
    *)  return 2 ;;  # could not reach GitHub
  esac
}


# Aborts before a build when a pinned ollama version does not exist. An empty
# argument means "not pinned" and is always fine. A check that could not be
# made is only a warning - the build itself will report the failure.
# Usage: assert_ollama_version "$OLLAMA_PIN"
assert_ollama_version() {
  [ -z "$1" ] && return 0
  ollama_version_exists "$1"
  case $? in
    1)
      echo -e "${RED}ERROR:${RESET}  ollama ${1} is not a published release"
      echo
      echo -e "${GREY}        Set OLLAMA_VERSION in .env to a published version, or to"
      echo -e "        'latest' to install the newest release - see"
      echo -e "        https://github.com/ollama/ollama/releases${RESET}"
      echo
      exit 1
      ;;
    2)
      echo -e "${ORANGE}WARN${RESET}    could not reach GitHub to verify ollama ${1}"
      echo "        continuing - the build will fail if that version does not exist"
      echo
      ;;
  esac
}


# Builds the image from the Dockerfile in the current directory, passing the
# CUDA version and any ollama pin through as build args. An empty pin builds
# against the latest ollama release.
# Usage: build_image webstop/ollama-bearer-auth:12.4.1 12.4.1 0.23.2
build_image() {
  docker build --no-cache \
    --build-arg CUDA_VERSION="$2" \
    --build-arg OLLAMA_VERSION="${3:-latest}" \
    -t "$1" .
}
