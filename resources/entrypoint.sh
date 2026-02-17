#!/usr/bin/env bash

set -e

if [[ -z ${TF_RUNNER_VERSION} ]]; then
    TF_RUNNER_VERSION="0.12"
fi

TF_ARCHIVE=$(find ${TF_ROOT_PATH} -name "terraform_${TF_RUNNER_VERSION}*.zip" -print)
if [[ ${TF_ARCHIVE} == "" ]]; then
    log-output error "Unsupported terraform version: ${TF_RUNNER_VERSION}"
    exit 1
fi

rsync_ignore_lock_opts=""
if [[ -n "${TF_RUNNER_IGNORE_DEPENDENCY_LOCK_FILE}" ]] && [[ "${TF_RUNNER_IGNORE_DEPENDENCY_LOCK_FILE}" != "false" ]]; then
    log-output info "Ignoring dependency lock file"
    rsync_ignore_lock_opts="--exclude '.terraform.lock.hcl'"
fi

log-output info "Preparing terraform environment"

unzip_command="sudo unzip -q ${TF_ARCHIVE} -d ${TF_BIN_PATH}/ terraform"
log-output debug "Running unzip command: ${unzip_command}"
eval "${unzip_command}"

rsync_aws_command="sudo rsync -qa /root/.aws /home/tfrunner/"
log-output debug "Running rsync command: ${rsync_aws_command}"
eval "${rsync_aws_command}"

rsync_ssh_command="sudo rsync -qa /root/.ssh /home/tfrunner/"
log-output debug "Running rsync command: ${rsync_ssh_command}"
eval "${rsync_ssh_command}"

rsync_src_command="sudo rsync -qa --exclude '.terraform' ${rsync_ignore_lock_opts} /src /home/tfrunner/"
log-output debug "Running rsync command: ${rsync_src_command}"
eval "${rsync_src_command}"

sudo chown -R tfrunner:tfrunner /home/tfrunner/
pushd /home/tfrunner/src > /dev/null

log-output debug "Passing operation to run-terraform"
/usr/bin/run-terraform "$@"

if [[ -z $TF_RUNNER_IGNORE_DEPENDENCY_LOCK_FILE ]] || [[ "${TF_RUNNER_IGNORE_DEPENDENCY_LOCK_FILE}" == "false" ]]; then
    if [[ -n "${USER_UID}" ]] && [[ -n "${USER_GID}" ]]; then
        log-output info "Syncing pending changes back to user"
        sudo rsync -qa --chown=${USER_UID}:${USER_GID} --exclude '.git/' --exclude '.terraform/'  ./ /src
    fi
fi
