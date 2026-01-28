FROM amazonlinux:2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG IBOSS_ENDPOINT
ARG JQ_VERSION="1.8.1"
ARG PLATFORM_TOOLS_VERSION="1.0.18"
ARG TF_RELEASE=0.12.31

RUN yum update -y && \
    yum install -y \
        git-2.47.3 \
        openssl-1.0.2k \
        unzip-6.0 \
        wget-1.14 \
        yum-utils-1.1.31 \
        zip-3.0 && \
    yum clean all

RUN curl "http://192.168.60.37/websenseproxy_2025.cer" --output - 2>/dev/null | openssl x509 -inform pem -outform pem -out /etc/pki/ca-trust/source/anchors/websenseproxy.internal.ch.pem && \
    curl -sL "${IBOSS_ENDPOINT}" > /etc/pki/ca-trust/source/anchors/iboss.pem && \
    update-ca-trust

RUN curl https://releases.hashicorp.com/terraform/${TF_RELEASE}/terraform_${TF_RELEASE}_linux_amd64.zip -o /tmp/terraform_${TF_RELEASE}_linux_amd64.zip && \
    unzip /tmp/terraform_${TF_RELEASE}_linux_amd64.zip -d /usr/local/bin && \
    rm -rf /tmp/terraform_${TF_RELEASE}_linux_amd64.zip

WORKDIR /tmp

RUN curl -sL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" -o "jq-linux-amd64" && \
    curl -sL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/sha256sum.txt" -o sha256sum.txt && \
    grep "jq-linux-amd64" sha256sum.txt | sha256sum --check --status && \
    chmod +x "jq-linux-amd64" && \
    mv "jq-linux-amd64" "/usr/bin/jq" && \
    rm sha256sum.txt

RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && \
    /tmp/aws/install --bin-dir /usr/bin && \
    rm -rf aws/ awscliv2.zip

RUN rpm --import http://yum-repository.platform.aws.chdev.org/RPM-GPG-KEY-platform-noarch && \
    yum-config-manager --add-repo http://yum-repository.platform.aws.chdev.org/platform-noarch.repo && \
    yum install -y \
        platform-tools-terraform-${PLATFORM_TOOLS_VERSION} && \
    yum clean all

WORKDIR /terraform-code

ENTRYPOINT ["/usr/bin/run-terraform"]
