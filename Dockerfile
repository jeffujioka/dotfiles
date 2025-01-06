# Build and run:
#   docker build --build-arg BASE_IMAGE=intent_dev:i2_dunfell --build-arg DEV_USER_NAME=$USER --build-arg=DEV_USER_PWD=1234 --build-arg DEV_UID=$(id -u) --build-arg DOMAINUSERS_GID=$(id -g) --rm -t dotfiles:latest -f Dockerfile .
#
# ssh credentials (test user):
#   ssh -t -p 3000 dev@localhost "bash --login"
#   ssh -t -p 3000 dev@localhost "cd ~/mbition/mbient/intent/ ; bash --login"

FROM ubuntu:22.04

# Update package lists and install SSH server
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y openssh-server sudo curl vim \
    && apt-get clean

ARG DEV_USER_NAME=dev
ARG DEV_USER_PWD=1234
ARG DEV_UID=365439264
ARG DOMAINUSERS_GID=2130182657
ARG DEV_HOME=/lhome/${DEV_USER_NAME}

ENV ROOT_PWD 1234
ENV RUSTUP_HOME=${DEV_HOME}/.rustup
ENV CARGO_HOME=${DEV_HOME}/.cargo

# ENV RUSTUP_HOME=/lhome/${DEV_USER_NAME}/.rustup
# ENV CARGO_HOME=/lhome/${DEV_USER_NAME}/.cargo

RUN groupadd -g ${DOMAINUSERS_GID} domainusers \
    && useradd -m -d ${DEV_HOME} ${DEV_USER_NAME} -u ${DEV_UID} -g domainusers \
    && usermod -a -G sudo ${DEV_USER_NAME} \
    && yes ${DEV_USER_PWD} | passwd ${DEV_USER_NAME} \
    && echo 'root:'${ROOT_PWD} | chpasswd

RUN usermod -s /bin/bash ${DEV_USER_NAME}

RUN mkdir /run/sshd
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b /usr/bin/
    # && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

COPY docker/scripts/sshd_dev_config /etc/ssh/
COPY docker/scripts/init_dev_docker.sh /usr/bin/
COPY bashrc ${DEV_HOME}/.bashrc
COPY config/starship.toml ${DEV_HOME}/.config/starship.toml
 
CMD ["/usr/bin/init_dev_docker.sh"]
