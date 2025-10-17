FROM amazonlinux:2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG JQ_VERSION="1.8.1"
ARG PLATFORM_TOOLS_VERSION="1.0.18"
ARG TARGETARCH
ARG TF_VERSIONS="0.12 0.13 1.3"
ARG TF_ROOT_PATH="/terraform"
ARG TF_BIN_PATH="/usr/bin"
ARG TF_USER="tfrunner"

ENV TF_ROOT_PATH=${TF_ROOT_PATH}
ENV TF_BIN_PATH=${TF_BIN_PATH}

RUN yum install -y \
    git \
    openssl \
    rsync \
    sha256sum \
    sudo \
    unzip \
    wget \
    zip && \
    yum clean all

RUN curl http://192.168.60.37/websenseproxy_A.cer --output - 2>/dev/null | openssl x509 -inform der -outform pem -out /etc/pki/ca-trust/source/anchors/websenseproxy.internal.ch.pem && \
    update-ca-trust

WORKDIR /tmp

RUN curl -sL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${TARGETARCH}" -o "jq-linux-${TARGETARCH}" && \
    curl -sL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/sha256sum.txt" -o sha256sum.txt && \
    grep "jq-linux-${TARGETARCH}" sha256sum.txt | sha256sum --check --status && \
    chmod +x "jq-linux-${TARGETARCH}" && \
    mv "jq-linux-${TARGETARCH}" "/usr/bin/jq" && \
    rm sha256sum.txt

RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-$(arch).zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && \
    /tmp/aws/install --bin-dir /usr/bin && \
    rm -rf aws/ awscliv2.zip

RUN rpm --import http://yum-repository.platform.aws.chdev.org/RPM-GPG-KEY-platform-noarch && \
    yum install -y yum-utils && \
    yum-config-manager --add-repo http://yum-repository.platform.aws.chdev.org/platform-noarch.repo && \
    yum install -y platform-tools-terraform-$PLATFORM_TOOLS_VERSION && \
    yum clean all

WORKDIR /

COPY /resources/tf_install.sh /tf_install.sh
COPY /resources/entrypoint.sh /entrypoint.sh
COPY /resources/tfrunner.sudoers /etc/sudoers.d/tfrunner

RUN useradd --uid 1000 --create-home --shell /bin/bash ${TF_USER} && \
    mkdir -p ${TF_ROOT_PATH} && \
    /tf_install.sh "${TF_VERSIONS}" "${TF_ROOT_PATH}"

RUN yum -y erase \
    sha256sum \
    wget && \
    yum clean all && \
    rm -f /tf_install.sh

WORKDIR /terraform-code

ENTRYPOINT ["/entrypoint.sh"]
