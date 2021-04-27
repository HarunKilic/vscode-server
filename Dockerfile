FROM quay.io/vektorlab/ctop as muhaki_ctop
FROM docker as muhaki_docker
FROM koalaman/shellcheck as muhaki_shellcheck
FROM debian:buster-slim

LABEL sh.muhaki.image        muhaki/code-server
LABEL sh.muhaki.maintainer   muhaki <info@novusweb.dk>
LABEL sh.muhaki.url          https://novusweb.dk
LABEL sh.muhaki.github       https://github.com/harunkilic
LABEL sh.muhaki.registry     https://hub.docker.com/u/muhaki


# Set default variables
ENV MUHAKI                   /muhaki
ENV MUHAKI_CODE_AUTH         password
ENV MUHAKI_CODE_BIND_ADDR    0.0.0.0:8080
ENV MUHAKI_CODE_CONFIG       /home/muhaki/.config/code-server
ENV MUHAKI_CODE_PASSWORD     muhaki
ENV MUHAKI_CONFIG            /etc/muhaki
ENV MUHAKI_LOG               /var/log/muhaki
ENV DOCKER_HOST              tcp://muhaki_socket:2375
ENV TERM                     xterm-256color
ENV TZ                       Europe/Copenhagen
# Support for old variables
ENV CODE_ROOT               "$MUHAKI"
ENV CODE_CONFIG             "$MUHAKI_CONFIG"
ENV CODE_LOG                "$MUHAKI_LOG"

# Packages
RUN set -ex; \
  apt-get update && apt-get install -y --no-install-recommends \
  bash \
  build-essential \
  bsdmainutils \
  ca-certificates \
  curl \
  dnsutils \
  git \
  gnupg \
  htop \
  iputils-ping \
  jq \
  less \
  nano \
  net-tools \
  openssh-client \
  procps \
  sudo \
  tzdata \
  unzip \
  util-linux \
  wget \
  zsh

# Configure Muhaki
RUN set -ex; \
  # Create muhaki user
  adduser --gecos '' --disabled-password muhaki; \
  # Update .bashrc
  echo 'PS1="$(whoami)@\h:\w \$ "' > /home/muhaki/.bashrc; \
  echo 'PS1="$(whoami)@\h:\w \$ "' > /root/.bashrc; \
  # Create muhaki directories
  install -d -m 0755 -o muhaki -g muhaki "$MUHAKI"; \
  install -d -m 0755 -o muhaki -g muhaki "$MUHAKI_CONFIG"; \
  install -d -m 0755 -o muhaki -g muhaki "$MUHAKI_LOG"; \
  # Oh-My-Zsh
  su -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" -s /bin/sh muhaki; \
  su -c "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/muhaki/.oh-my-zsh/custom/themes/powerlevel10k" -s /bin/sh muhaki; \
  su -c "git clone https://github.com/zsh-users/zsh-autosuggestions.git /home/muhaki/.oh-my-zsh/custom/plugins/zsh-autosuggestions" -s /bin/sh muhaki; \
  su -c "git clone https://github.com/TamCore/autoupdate-oh-my-zsh-plugins.git /home/muhaki/.oh-my-zsh/custom/plugins/autoupdate" -s /bin/sh muhaki; \
  sed -i 's|source $ZSH/oh-my-zsh.sh|source "$MUHAKI_CONFIG"/.muhakirc\nsource $ZSH/oh-my-zsh.sh|g' /home/muhaki/.zshrc; \
  # Change user shell
  sed -i "s|/home/muhaki:/sbin/nologin|/home/muhaki:/bin/zsh|g" /etc/passwd

# Imports
COPY --from=muhaki_ctop /ctop /usr/local/bin/ctop
COPY --from=muhaki_docker /usr/local/bin/docker /usr/local/bin/docker
COPY --from=muhaki_shellcheck /bin/shellcheck /usr/local/bin/shellcheck
COPY --chown=root:root bin /usr/local/bin
COPY --chown=muhaki:muhaki config "$MUHAKI_CONFIG"

# Configure code-server
RUN set -ex; \
  # Get code-server
  CODE_VERSION="$(curl -sL https://api.github.com/repos/cdr/code-server/releases/latest | jq -r .tag_name)"; \
  if [ -z "$CODE_VERSION" ]; then CODE_VERSION=v3.8.0; fi; \
  CODE_VERSION_NUMBER="$(echo "$CODE_VERSION" | sed 's|v||g')"; \
  curl -sL https://github.com/cdr/code-server/releases/download/"$CODE_VERSION"/code-server-"$CODE_VERSION_NUMBER"-linux-amd64.tar.gz -o /tmp/code-server-"$CODE_VERSION"-linux-amd64.tar.gz; \
  tar -xzf /tmp/code-server-"$CODE_VERSION"-linux-amd64.tar.gz -C /tmp; \
  mv /tmp/code-server-"$CODE_VERSION_NUMBER"-linux-amd64 /usr/local/lib/code-server; \
  # Create code-server directories
  install -d -m 0755 -o muhaki -g muhaki "$MUHAKI_CODE_CONFIG"/data/User; \
  install -d -m 0755 -o muhaki -g muhaki "$MUHAKI_CODE_CONFIG"/extensions; \
  # Copy settings.json
  cp "$MUHAKI_CONFIG"/settings.json "$MUHAKI_CODE_CONFIG"/data/User/settings.json; \
  # Symlink code-server
  ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server; \
  # Install default extensions
  code-server --extensions-dir="$MUHAKI_CODE_CONFIG"/extensions \
  --install-extension=equinusocio.vsc-material-theme \
  --install-extension=pkief.material-icon-theme \
  --install-extension=remisa.shellman \
  --install-extension=ryu1kn.partial-diff \
  --install-extension=timonwong.shellcheck; \
  # Custom fonts
  sed -i "s|</head>|\
  <style> \n\
  @font-face { \n\
  font-family: 'MesloLGS NF'; \n\
  font-style: normal; \n\
  src: url('https://muhaki.sh/fonts/meslolgs-nf-regular.woff') format('woff'), \n\
  url('https://muhaki.sh/fonts/meslolgs-nf-bold.woff') format('woff'), \n\
  url('https://muhaki.sh/fonts/meslolgs-nf-italic.woff') format('woff'), \n\
  url('https://muhaki.sh/fonts/meslolgs-nf-bold-italic.woff') format('woff'); \n\
  } \n\
  \n\</style></head>|g" /usr/local/lib/code-server/src/browser/pages/vscode.html; \
  # Finalize code-server
  chown -R muhaki:muhaki "$MUHAKI_CODE_CONFIG"; \
  chown -R muhaki:muhaki "$MUHAKI_CONFIG"; \
  cp -rp "$MUHAKI_CODE_CONFIG" "$MUHAKI_CONFIG"

# Finalize
RUN set -ex; \
  # ctop 
  cp "$MUHAKI_CONFIG"/ctop /home/muhaki/.ctop; \
  # sudo
  echo "muhaki ALL=(ALL) NOPASSWD: /usr/bin/apt" > /etc/sudoers.d/muhaki; \
  # Set ownership
  chown -R root:root /usr/local/bin; \
  # Cleanup
  rm -rf /var/lib/apt/lists/*; \
  rm -rf /tmp/*

EXPOSE 8080

WORKDIR /home/muhaki

USER muhaki

ENTRYPOINT ["muhaki-entrypoint"]