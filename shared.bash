#!/usr/bin/env bash

main() {
  setup_aliases() {
    alias vim=nvim
    alias vi=nvim
    alias ll="ls -al"
    alias be="bundle exec"
    alias bake="bundle exec rake"
    alias drm='docker rm $(docker ps -a -q)'
    alias drmi='docker rmi $(docker images -q)'
    alias bosh2=bosh

    #git aliases
    alias gst="git status"
    alias gd="git diff"
    alias gap="git add -p"
    alias gup="git pull -r"
    alias gp="git push"
    alias ga="git add"
    git config --global alias.yolo '!git commit -m "$(curl -s whatthecommit.com/index.txt)"'

    alias gbt="gobosh_target"
    alias gbtl="gobosh_target_lite"
    alias cft="cf_target"
    alias cftl="cf_target local"
    alias t="target"

    alias rg="ag"

    alias h?="history | grep"
    alias chg="credhub_get"

    alias local_ginkgo="/Users/pivotal/go/bin/ginkgo"

    #kubectl aliases
    alias k="kubectl"
    alias kobectl="kubectl"
    # Get current context
    alias krc='kubectl config current-context'
    # List all contexts
    alias klc='kubectl config get-contexts -o name | sed "s/^/  /;\|^  $(krc)$|s/ /*/"'
    # Change current context
    alias kcc='kubectl config use-context "$(klc | fzf -e | sed "s/^..//")"'
    complete -F __start_kubectl k #enable bash auto-completion for k
  }

  setup_environment() {
    export CLICOLOR=1
    export LSCOLORS exfxcxdxbxegedabagacad

    # go environment
    export GOPATH=$HOME/go

    # git duet config
    export GIT_DUET_GLOBAL=true
    export GIT_DUET_ROTATE_AUTHOR=1
    export GIT_DUET_CO_AUTHORED_BY=1

    # setup path
    export PATH=$GOPATH/bin:$PATH:/usr/local/go/bin:$HOME/scripts:/usr/ocal/opt/apr/bin:/usr/local/opt/apr-util/bin:/usr/local/sbin:/usr/local/kubebuilder/bin
    export PATH="/usr/local/opt/libexec/gnubin:$PATH";
    export EDITOR=nvim

    # mac os catalina plz don't complain about bash
    export BASH_SILENCE_DEPRECATION_WARNING=1
  }

  setup_rbenv() {
    eval "$(rbenv init -)"
  }

  setup_fasd() {
    local fasd_cache
    fasd_cache="$HOME/.fasd-init-bash"

    if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache" ]; then
      fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| "$fasd_cache"
    fi

    source "$fasd_cache"
    eval "$(fasd --init auto)"
  }

  setup_completions() {
    [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion
    complete -C aws_completer aws
    source <(kubectl completion bash)
    complete -W "\`find . -iname \"*akefil*\" | grep -v vendor | xargs -I {} grep -hoE '^[a-zA-Z0-9_.-]+:([^=]|$)' {} | sed 's/[^a-zA-Z0-9_.-]*$//' | sort -u\`" make

    # target completion
    source "${HOME}/workspace/networking-workspace/target-completion.bash"
  }

  setup_direnv() {
    eval "$(direnv hook bash)"
  }

  setup_gitprompt() {
    if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
      # git prompt config
      export GIT_PROMPT_SHOW_UNTRACKED_FILES=normal
      export GIT_PROMPT_ONLY_IN_REPO=0
      export GIT_PROMPT_THEME="Custom"

      source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
    fi
  }

  setup_ssh_agent() {
    if [[ ! -e ~/.ssh_agent ]]; then
      if [[ -n ${SSH_AUTH_SOCK} ]]; then
        ln -sf $SSH_AUTH_SOCK ~/.ssh_agent
      fi
    fi

    export SSH_AUTH_SOCK=~/.ssh_agent
  }

  setup_bosh_env_scripts() {
    local bosh_scripts
    bosh_scripts="${HOME}/workspace/networking-oss-deployments/scripts/script_helpers.sh"
    [[ -s "${bosh_scripts}" ]] && source "${bosh_scripts}"
  }

  setup_gpg_config() {
    local status
    status=$(gpg --card-status &> /dev/null; echo $?)

    if [[ "$status" == "0" ]]; then
      export SSH_AUTH_SOCK="${HOME}/.gnupg/S.gpg-agent.ssh"
    fi
  }

  setup_base16() {
    # Base16 Shell
    BASE16_SHELL="$HOME/.config/base16-shell/"
    [ -n "$PS1" ] && \
        [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
            eval "$("$BASE16_SHELL/profile_helper.sh")"
  }

  setup_fzf() {
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash
  }

  local dependencies
    dependencies=(
        aliases
        base16
        environment
        rbenv
        fasd
        completions
        direnv
        gitprompt
        # gpg_config
        bosh_env_scripts
        ssh_agent
        fzf
      )

  for dependency in ${dependencies[@]}; do
    eval "setup_${dependency}"
    unset -f "setup_${dependency}"
  done
}

main
unset -f main

# FUNCTIONS

function reload() {
  source "${HOME}/.bash_profile"
}

reinstall() {
  local workspace
  workspace="~/workspace/networking-workspace"

  if [[ ! -d "${workspace}" ]]; then
    git clone https://github.com/cloudfoundry/networking-workspace "${workspace}"
  fi

  pushd "${workspace}" > /dev/null
    git diff --exit-code > /dev/null
    if [[ "$?" = "0" ]]; then
      git pull -r
      bash -c "./install.sh"
    else
      echo "Cannot reinstall. There are unstaged changes in the networking-workspace repo."
      git diff
    fi
  popd > /dev/null
}

cf_seed() {
  cf create-org o
  cf create-space -o o s
  cf target -o o -s s
}

cf_clean() {
  : "${1?"Please provide a target to delete. For example: cf_clean \"CATS|SMOKE|SCALING\""}"
  cf buildpacks | grep -E "${1}" | awk '{ print $1 }' | xargs -n 1 -P 8 cf delete-buildpack -f
  cf orgs | grep -E "${1}" | grep -v persistent | xargs -n 1 -P 8 cf delete-org -f
  cf quotas | grep -E "${1}" | grep -v persistent | awk '{ print $1 }' | xargs -n 1 -P 8 cf delete-quota -f
}

gimme_certs() {
	local common_name
	common_name="${1:-fake}"
	local ca_common_name
	ca_common_name="${2:-${common_name}_ca}"
	local depot_path
	depot_path="${3:-fake_cert_stuff}"
	certstrap --depot-path ${depot_path} init --passphrase '' --common-name "${ca_common_name}"
	certstrap --depot-path ${depot_path} request-cert --passphrase '' --common-name "${common_name}"
	certstrap --depot-path ${depot_path} sign --passphrase '' --CA "${ca_common_name}" "${common_name}"
}

bbl_gcp_creds () {
  lpass show "BBL GCP Creds" --notes
}

eval_bbl_gcp_creds() {
  eval "$(bbl_gcp_creds)"
}

pullify() {
  git config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
  git fetch origin
}

istio_docker() {
  local istio_dir
  istio_dir="${1}"

  if [[ -z "${istio_dir}" ]]; then
    echo "WARNING: istio_dir not set"
    echo "Setting istio directory to ${GOPATH}/src/istio.io/istio"
    echo "You may optionally pass your preferred istio directory as the first argument 😀 "
    istio_dir="${GOPATH}/src/istio.io/istio"
  else
    echo "istio_directory set to ${istio_dir}"
  fi

  local image
  image="gcr.io/istio-testing/istio-builder:latest"
  echo "Getting most recent $image..."
  docker pull $image

  docker run -u root -it --cap-add=NET_ADMIN -v /var/run/docker.sock:/var/run/docker.sock -v "${istio_dir}":/go/src/istio.io/istio "${image}" /bin/bash
}

default_hours() {
  local current_hour=$(date +%H | sed 's/^0//')
  local result=$((17 - current_hour))
  if [[ ${result} -lt 1 ]]; then
    result=1
  fi
  echo -n ${result}
}

set_key() {
  local hours=$1

  /usr/bin/ssh-add -D

  echo "Setting hours to: $hours"
  lpass show --notes 'ProductivityTools/id_rsa' | /usr/bin/ssh-add -t ${hours}H -
}

set-git-keys() {
  local email=$1
  local hours=$2

  if [[ -z ${email} ]]; then
    echo "Usage: $0 [LastPass email or git author initials] [HOURS (optional)]"
    return
  fi

  if git_author_path "/authors/$email" >/dev/null 2>&1; then
    echo "Adding key for $(bosh int ${HOME}/.git-authors --path="/authors/$email" | sed 's/;.*//')"
    email="$(bosh int ${HOME}/.git-authors --path="/authors/$email" | sed 's/;.*//')@$(bosh int ${HOME}/.git-authors --path="/email/domain")"
  fi

  if [[ -z ${hours} ]]; then
    hours=$(default_hours)
  fi

  if ! [[ $(lpass status) =~ $email ]]; then
    lpass login "$email"
  fi
  set_key ${hours}
}

function pks_login() {
  local environment=$1
  local path_to_metadata="${HOME}/workspace/pks-networking-env-metadata/${environment}/metadata.json"

  local pks_api=$(jq -r .pks_api.url "${path_to_metadata}")
  local pks_user=$(jq -r .pks_api.uaa_admin_user "${path_to_metadata}")
  local pks_password=$(jq -r .pks_api.uaa_admin_password "${path_to_metadata}")

  export OM_SKIP_SSL_VALIDATION=true
  export OM_TARGET=$(jq -r .ops_manager.url "${path_to_metadata}")
  export OM_USERNAME=$(jq -r .ops_manager.username "${path_to_metadata}")
  export OM_PASSWORD=$(jq -r .ops_manager.password "${path_to_metadata}")

  pks login -a $pks_api -u $pks_user -p $pks_password --skip-ssl-validation
}

function pks_metadata() {
  local environment=$1
  cat $HOME/workspace/pks-networking-env-metadata/$environment/metadata.json | jq .
}

function current_branch() { # Gets current branch
  git rev-parse --abbrev-ref HEAD
}

function parse_branch() { # Gets current branch with parens around it for some legacy things
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

function gh_remote_path() { # Parses the 'remote path' of the repo: username/repo
  REMOTE=${1:-origin}

  GH_PATH=`git remote -v | tr ':' ' ' | tr '.' ' ' | grep $REMOTE | awk '/push/ {print $4}'`
  echo ${GH_PATH#com/}
}

function opengh() { # Opens current branch on Github, works for all repos
  REMOTE=${1:-origin}

  echo 'Opening branch on Github...'
  open "https://github.com/$(gh_remote_path $REMOTE)/tree/$(current_branch)"
}

function newpr() { # Opens current branch on Github in the "Open a pull request" compare view
  echo 'Opening compare on Github...'
  open "https://github.com/$(gh_remote_path)/compare/$(current_branch)?expand=1"
}

function gpu() { # Push upstream
  git push --set-upstream origin `current_branch`
}

function mkd() { # Create a new directory and enter it
  mkdir -p "$@" && cd "$_";
}

function loop() { # Repeats a given command forever
  local i=2 t=1 cond

  [ -z ${1//[0-9]/} ] && i=$1 && shift
  [ -z ${1//[0-9]/} ] && t=$1 && shift && cond=1
  while [ $t -gt 0 ]; do
    sleep $i
    [ $cond ] && : $[--t]
    $@
  done
}

function server() { # Create webserver from current directory
  local port="${1:-8000}";
  echo "Links to give out:"
  ifconfig | grep "inet.*netmask" | sed "s/inet \(.*\) netmask.*/http:\/\/\1:$port\//g"
  sleep 1 && open "http://localhost:${port}/" &
  docker run -p $port:80 -v $(pwd):/usr/share/nginx/html jrelva/nginx-autoindex
}

function mdserve() {
  local port="${1:-8000}";
  echo "Links to give out:"
  ifconfig | grep "inet.*netmask" | sed "s/inet \(.*\) netmask.*/http:\/\/\1:$port\//g"
  sleep 1 && open "http://localhost:${port}/" &
  docker run --rm -p $port:8080 -v $(pwd):/app/contents titpetric/pendulum
}

function nuke() { # Straight up murders all processes matching first arg
  ps ax | grep $1 | grep -v grep | awk '{print $1}' | xargs kill -9
}

function politely_nuke() { # As above but nicely
  ps ax | grep $1 | grep -v grep | awk '{print $1}' | xargs kill
}

function smart_bomb() { # Don't use this
  killall -15 $1 2> /dev/null || killall -2 $1 2> /dev/null || killall -1 $1 2> /dev/null || killall -9 $1 2> /dev/null
}

function clear_port() { # Finds whatever is using a given port (except chrome) and kills it
  lsof -t -i tcp:$1 | ag -v "$(ps aux|ag Chrome|tr -s ' '|cut -d ' ' -f 2|fmt -1024|tr ' ' '|')"| xargs kill -9
}

function v() { # Use fasd to open a file in vim from anywhere
  nvim `f "$1" | awk "{print $2}"`
}

function credhub_get() {
  credhub get -n `credhub find -n "$1" | grep "name" | head -n 1 | sed 's/- name: //'`
}

function toolsmiths() {
  echo "Opening https://environments.toolsmiths.cf-app.com..."
  open https://environments.toolsmiths.cf-app.com
  echo "NOTE: Run create_service_account_key_for_toolsmiths_env <story_id>"
  echo "      to create a service account with a key for toolsmiths env."
}

function old() {
  mv $1 $1.old
}

function target-smith-deployment() {
  local smith_env=${1:-$env}

  if [[ -z ${smith_env} ]]; then
    echo "Usage: $0 [claimed from smith env name]"
    echo 'If env is not provided the `env` environment variable will be used, if it is empty, the execution will be aborted'
    return 1
  fi

  echo "Retreving the deployment name..."
  d=$(smith -e ${smith_env} bosh -- deployments --column "Name" --json | jq ".Tables[0].Rows[0].name" -r)
  if [[ -z ${d} ]]; then
    echo "Looks like your API key is not exported, try to run export-smith-token first"
    return 1
  fi
  echo "Deployment is ${d}"
  echo "Making smith-bosh alias"
  alias smith-bosh="smith -e ${smith_env} bosh -- -d ${d}"
}

cf_target() {
  if [ $# = 0 ]; then
    echo "missing environment-name"
    echo ""
    echo "example usage:"
    echo "cft environment-name"
    return
  fi
  env=$1

  if [ "$env" = "ci" ]; then
    echo "no CF deployed in ci env."
    return
  fi

  if [ -f "${HOME}/workspace/networking-oss-deployments/environments/${1}/cats_integration_config.json" ]; then
    password=$(jq -r '.admin_password' < "${HOME}/workspace/networking-oss-deployments/environments/${1}/cats_integration_config.json")
  else
    password=$(credhub get -n "/bosh-${env}/cf/cf_admin_password" | bosh int --path /value -)
    uaa_password=$(credhub get -n "/bosh-${env}/cf/uaa_admin_client_secret" | bosh int --path /value -)
  fi

  [ -f "${HOME}/workspace/networking-oss-deployments/environments/${1}/cats_integration_config.json" ] && workspace="cf-k8s" || workspace="routing"

  if [ "$env" = "pickelhelm" ] || [ "$env" = "toque" ] || [ "$env" = "mitre" ] || [ "$env" = "caubeen" ]; then
    # we don't make c2c envs anymore. Everything else should use the routing domain.
    system_domain="${env}.c2c.cf-app.com"
  else
    system_domain="${env}.routing.cf-app.com"
  fi

  cf api "api.${system_domain}" --skip-ssl-validation
  cf auth admin "${password}"

  if [ -n "${uaa_password}" ]; then
    uaac target "login.${system_domain}" --skip-ssl-validation
    uaac token client get admin -s "${uaa_password}"
  fi

  cf_seed
}

gobosh_target() {
  gobosh_untarget
  if [ $# = 0 ]; then
    return
  fi

  export BOSH_ENV=$1
  export BOSH_DIR="$(lookup_env $BOSH_ENV)"

  changes="$(git -C ${BOSH_DIR} status --porcelain)"
  exit_code="${?}"
  if [[ "${exit_code}" -eq 0 ]] && [[ -z "${changes}" ]]; then
    git -C $BOSH_DIR pull
  fi

  pushd $BOSH_DIR 1>/dev/null
      eval "$(bbl print-env)"
  popd 1>/dev/null

  export BOSH_DEPLOYMENT="cf"
}

function gke_target() {
  local line="$(gcloud container clusters list 2>/dev/null | grep "$1")"
  local name="$(echo "${line}" | awk '{print $1}')"
  local zone="$(echo "${line}" | awk '{print $2}')"

  if [ -z "${name}" ]; then
    return
  fi

  gcloud container clusters get-credentials "${name}" --zone "${zone}"
}

lookup_env() {
  local name=${1}

  ls ~/workspace/networking-oss-deployments/environments/$1/bbl-state > /dev/null 2>&1
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo "${HOME}/workspace/networking-oss-deployments/environments/$1/bbl-state"
    return
  fi

  ls ~/workspace/networking-oss-deployments/environments/$1 > /dev/null 2>&1
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo "${HOME}/workspace/networking-oss-deployments/environments/$1"
    return
  fi
}

gobosh_untarget() {
  unset BOSH_ENV
  unset BOSH_DIR
  unset BOSH_USER
  unset BOSH_PASSWORD
  unset BOSH_ENVIRONMENT
  unset BOSH_GW_HOST
  unset BOSH_GW_PRIVATE_KEY
  unset BOSH_CA_CERT
  unset BOSH_DEPLOYMENT
  unset BOSH_CLIENT
  unset BOSH_CLIENT_SECRET
}

target() {
  gobosh_target "${@}"
  cf_target "${@}"
  gke_target "${@}"
}

readd_local_route() {
  ips="10.244.0.0/16"
  gw="192.168.50.6"
  sudo route delete -net "$ips" "$gw"
  sudo route add -net "$ips" "$gw"
}

gobosh_build_manifest() {
  bosh -d cf build-manifest -l=$BOSH_DIR/deployment-env-vars.yml --var-errs ~/workspace/cf-deployment/cf-deployment.yml
}

extract_manifest() {
  bosh task $1 --debug | deployment-extractor
}

create_upload() {
  bosh create-release --force --timestamp-version && bosh upload-release
}

upload_bosh_stemcell() {
  STEMCELL_VERSION="$(bosh int ~/workspace/cf-deployment/cf-deployment.yml --path=/stemcells/0/version)"
  echo "will upload stemcell ${STEMCELL_VERSION}"
  bosh -e vbox upload-stemcell "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent?v=${STEMCELL_VERSION}"
}

function windows_port_forward() {
  echo "Port forwarding from $1"
  ssh -f -L 3389:$1:3389 -N -i ${BOSH_GW_PRIVATE_KEY} ${BOSH_GW_USER}@${BOSH_GW_HOST}
}

function create_service_account_key_for_toolsmiths_env() {
  if [[ $# != 1 ]]; then
    echo "Usage: create_service_account_key_for_toolsmiths_env <story_id>"
    return 1
  fi

  local story_id="${1}"
  local service_account_name="opsman-${story_id}"
  local gcp_project_name="$(gcloud config get-value project)"
  local service_account_email="${service_account_name}@${gcp_project_name}.iam.gserviceaccount.com"
  local key_file_name="$(mktemp)"

  gcloud iam service-accounts create "${service_account_name}" \
    --display-name "${service_account_name}" 1> /dev/null
  gcloud projects add-iam-policy-binding "${gcp_project_name}" \
    --member "serviceAccount:${service_account_email}" \
    --role roles/editor 1> /dev/null
  gcloud iam service-accounts keys create "${key_file_name}" \
    --iam-account "${service_account_email}" 1> /dev/null

  echo "NOTE: Remember to clean up your key after your done using remove_service_account_key_for_toolsmiths_env." 1>&2

  cat "${key_file_name}"
  rm "${key_file_name}"
}

function remove_service_account_key_for_toolsmiths_env() {
  if [[ $# != 1 ]]; then
    echo "Usage: remove_service_account_key_for_toolsmiths_env <story_id>"
    return 1
  fi

  local story_id="${1}"
  local gcp_project_name="$(gcloud config get-value project)"
  local service_account_email="opsman-${story_id}@${gcp_project_name}.iam.gserviceaccount.com"

  gcloud iam service-accounts delete "${service_account_email}"
}

function pull_if_no_dirty_changes(){
  echo "Pulling ${1}..."
  local dirty_changes="$(git -C ${1} status --porcelain)"
  local unpushed_commits="$(git -C ${1} lg origin..)"
  if [[ -z "${dirty_changes}" && -z "${unpushed_commits}" ]]; then
    git -C "${1}" pull
  else
    echo "Not pulling ${1} since it has local work"
  fi
}

function good_morning(){
  echo "Pulling all the repos..."

  # Routing Datadog Config: Configure your Data 🐶
  pull_if_no_dirty_changes "${HOME}/workspace/routing-datadog-config"

  # Routing Team Checklists: Checklists (on-call, onboarding) and a kind of helpful wiki
  pull_if_no_dirty_changes "${HOME}/workspace/routing-team-checklists"

  # Networking Program Checklists: Checklists (on-call, onboarding) and a kind of helpful wiki
  pull_if_no_dirty_changes "${HOME}/workspace/networking-program-checklists"

  # Bosh Deployment: We usually use this to bump golang in our releases
  pull_if_no_dirty_changes "${HOME}/workspace/bosh-deployment"

  # CF Deployment: We use it to deploy Cloud Foundries
  pull_if_no_dirty_changes "${HOME}/workspace/cf-deployment"

  # CF Deployment Concourse Tasks: We use it to deploy Concourses
  pull_if_no_dirty_changes "${HOME}/workspace/cf-deployment-concourse-tasks"

  # CF Acceptance Test: 🐱 🐱  or CATS. Happy path integration tests for CF
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/cf-acceptance-tests"

  # CF Smoke Tests: Quick test that pretty much just pushes an app to verify a successful deployment of CF
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/cf-smoke-tests"

  # NATS Release: Inherited from Release Integration. We now own this release, which deploys NATS, which is used in CF
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/nats-release"

  # Istio Acceptance Tests: Used to verify Cloud Foundry integration with Istio using real environments and real components
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/istio-acceptance-tests"

  # Istio Release: BOSH release used to deploy Istio, Envoy, Copilot
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/istio-release"

  # Istio Workspace: Use this if you want to work outside of your GOPATH and spin up a Vagrant VM for testing (see istio_docker())
  pull_if_no_dirty_changes "${HOME}/workspace/istio-workspace"

  # Routing API CLI: Used to interact with the Routing API, which can be found in Routing Release
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/routing-api-cli"

  # Toque Scaling: Scaling tests in the C2c CI
  pull_if_no_dirty_changes "${HOME}/workspace/toque-scaling"

  # Toque Test Helpers: Fixtures for the toque scaling tests
  pull_if_no_dirty_changes "${HOME}/workspace/toque-test-helpers"

  # CF Networking Release: BOSH release for policy-based container networking in Cloud Foundry
  pull_if_no_dirty_changes "${HOME}/workspace/cf-networking-release"

  # Routing Perf Release: Used to run performance tests against Routing Release
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/routing-perf-release"

  # Routing Release: BOSH Release home to the Gorouter, TCP router, and a bunch of other routing related things. Spelunk! Refactor!
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/routing-release"

  # Routing Sample Apps: Mostly used by developers and PMs for debugging and acceptance. If you don't see what you need, make it and add extensive documentation.
  pull_if_no_dirty_changes "${HOME}/workspace/routing-sample-apps"

  # Docs Book CloudFoundry: You'll need this if you want to make any documentation changes for the Cloud Foundry docs site.
  pull_if_no_dirty_changes "${HOME}/workspace/docs-book-cloudfoundry"

  # Docs Running CF: You'll need this if you want to run a docs site locally to make sure your changes are OK.
  pull_if_no_dirty_changes "${HOME}/workspace/docs-running-cf"

  # Istio Scaling: Used to test the scalability of Istio in a Cloud Foundry deployment
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/istio-scaling"

  # Community Bot: an ever changing tool to help with our community responsibilities
  pull_if_no_dirty_changes "${GOPATH}/src/github.com/cf-routing/community-bot"

  # Zero Downtime Release: BOSH release for testing app availability
  pull_if_no_dirty_changes "${HOME}/workspace/zero-downtime-release"

  # Diego Release: BOSH release for container scheduling for Cloud Foundry Runtime
  pull_if_no_dirty_changes "${HOME}/workspace/diego-release"

  # Capi Release: BOSH release for the Cloud Controller API
  pull_if_no_dirty_changes "${HOME}/workspace/capi-release"

  # Garden RunC Release: BOSH release for Garden RunC
  pull_if_no_dirty_changes "${HOME}/workspace/garden-runc-release"

  # Silk: Open-source, CNI-compatible container networking fabric
  pull_if_no_dirty_changes "${GOPATH}/src/code.cloudfoundry.org/silk"

  # Cf Networking Helpers: Helpers for running tests?
  pull_if_no_dirty_changes "${HOME}/workspace/cf-networking-helpers"

  # Pivotal Only ==============================================================================================

  # Routing Support Notes: List of support tickets, past and present, and a handy template to start your own.
  pull_if_no_dirty_changes "${HOME}/workspace/routing-support-notes"

  # Scripts for generating Istio config for PKS Routing
  pull_if_no_dirty_changes "${GOPATH}/src/github.com/pivotal/k8s-istio-resource-generator"

  # PKS service mesh
  pull_if_no_dirty_changes "${GOPATH}/src/github.com/pivotal/ingress-router"

  # Pivotal Networking CI -- pipeline and tasks for pivotal ci
  pull_if_no_dirty_changes "${GOPATH}/src/github.com/pivotal/pivotal-networking-ci"

  # PKS Networking Env Metadata-- env info for pivotal ci
  pull_if_no_dirty_changes "${GOPATH}/workspace/pks-networking-env-metadata"

  # PKS Networking Env Metadata-- env info for pivotal ci
  pull_if_no_dirty_changes "${GOPATH}/src/github.com/pivotal-cf/norsk-config"
}

function forever() {
  c=0
  while true
  do
    c=$((c+1))
    echo "Run #$c"
    $@
    sleep 0.5
  done
}

function zoom() {
  local who="${1}"

  if [[ -n "${who}" ]]; then
    echo "Zooming ${who}.networking.family..."
    open "http://${who}.networking.family"
  else
    echo "Usage: zoom <who-to-zoooooom> *Must have a networking.family subdomain."
  fi
}

function random_theme(){
  themes=($(ls /Users/pivotal/.config/base16-shell/scripts/))
  total_themes=${#themes[@]}
  random_theme_number=$((RANDOM % total_themes))
  random_theme=${themes[${random_theme_number}]}
  echo "Your cool new random theme is ${random_theme/-/_}"
  _base16 "/Users/pivotal/.config/base16-shell/scripts/${random_theme}" $(basename ${random_theme#"base16-"} .sh)
}

function ship_it(){
  binary="${1}"
  vm="${2}"
  service="${3}"
  echo "☁️  Building and deploying a new version of $binary..."
  GOOS=linux go build -o $binary cmd/$binary/main.go
  if [ "$?" = "0" ]; then
    bosh scp $binary $vm:/tmp/
    bosh ssh $vm -c "sudo mv /tmp/$binary /var/vcap/packages/$service/bin/$binary; sudo /var/vcap/bosh/bin/monit restart $service"
    echo "👨🏽‍✈️Done!"
  else
    printf "🚨 Wee woo wee woo 🚨\nCould not compile $binary!\nMake sure you're in the correct directory, and there are no compilation errors.\n" 1>&2
  fi
}

alias ship_copilot="ship_it copilot-server istio-control copilot"
alias ship_pilot="ship_it pilot-discovery istio-control pilot-discovery"
alias ship_policy_server="ship_it policy-server api policy-server"
alias ship_policy_server_internal="ship_it policy-server-internal api policy-server-internal"

function restart_envoy(){
  bosh ssh istio-router -c "sudo /var/vcap/bosh/bin/monit restart envoy"
}

function ws(){
  sesh="${1}"

  tmux kill-session -t $sesh
  tmux new-session -A -s $sesh "tmux source-file ~/workspace/networking-workspace/tmux_workspaces/${sesh}"
}

function kws(){
  sesh="${1}"

  tmux kill-session -t $sesh
}

function ips() {
  ifconfig | grep "inet.*netmask" | sed "s/inet \(.*\) netmask.*/\1/g"
}

function update_fly() {
  if [[ -z "$1" ]]; then
    echo "Usage 'update_fly <domain>'"
  else
    wget "https://$1/api/v1/cli?arch=amd64&platform=darwin" -O fly
    chmod +x fly
    sudo mv fly $(which fly)
  fi
}

function smith_target() {
  if [ "$#" -lt 1 ]; then
    echo "incorrect paramaters. usage: $0 <smith-env-name>"
    echo ""
    echo "this script will target cf and will provide the env vars needed to target bosh"
    echo "you can run this command with eval to target bosh"
    echo "for example..."
    echo "eval '\$($0 <smith-env-name>)'"
    echo ""
    exit 1
  fi

  smith_env_name=$1

  (
    export env=$smith_env_name
    bosh_vars=$(smith bosh)
    cf_deployment=$(smith bosh deployments -- --json | jq .Tables[0].Rows[0].name)
    eval cf_deployment=$cf_deployment
    smith cf-login >/dev/null
    echo "export env=$smith_env_name"
    echo "$bosh_vars"
    echo "export BOSH_DEPLOYMENT=$cf_deployment"
    echo "export BOSH_ENV=$smith_env_name"
  )
}

function gssh() {
  gcloud compute ssh --zone us-central1-a  --project cf-routing pivotal@$1
}

source $HOME/workspace/networking-workspace/custom-commands.sh

