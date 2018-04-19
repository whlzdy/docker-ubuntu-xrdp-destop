FROM ubuntu:16.04
MAINTAINER wisfern@gmail.com

# Install packages
ENV DEBIAN_FRONTEND=noninteractive BUILD_DEPS="libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev"
RUN sed -i 's#http://archive.ubuntu.com/#http://mirrors.aliyun.com/#;s#http://security.ubuntu.com/#http://mirrors.aliyun.com/#;s#\# deb-src#deb-src#' /etc/apt/sources.list \
    && apt-get -y update \
    && apt-get -yy upgrade \
    && apt-get -yy install \ 
        apt-utils software-properties-common ca-certificates \
        xfce4 xfce4-terminal xfce4-screenshooter xfce4-taskmanager \
        xfce4-clipman-plugin xfce4-cpugraph-plugin xfce4-netload-plugin \
        xfce4-xkb-plugin xauth uuid-runtime pulseaudio locales pepperflashplugin-nonfree \
        sudo git wget cmake vim zsh curl net-tools inetutils-ping \
        firefox supervisor openssh-server nginx firefox-locale-zh-hant \
        language-pack-zh-hant language-pack-gnome-zh-hant ttf-ubuntu-font-family \
        fonts-wqy-microhei python-pip python-dev build-essential \
        libev-dev libmpdec-dev libjansson-dev libssl-dev libgnutls-dev libmysqlclient-dev libhttp-parser-dev \
        libcurl4-openssl-dev libldap2-dev libkrb5-dev libalberta-dev libgss-dev libidn11-dev librtmp-dev \
        $BUILD_DEPS

# Build rdkafka

WORKDIR /tmp
RUN git clone https://github.com/edenhill/librdkafka.git \
    && cd librdkafka \
    && ./configure \
    && make -j 4 \
    && make install 

# Build xrdp

WORKDIR /tmp
RUN apt-get source pulseaudio \
    && apt-get build-dep -yy pulseaudio \
    && cd /tmp/pulseaudio-8.0 \
    && dpkg-buildpackage -rfakeroot -uc -b \
    && cd /tmp \
    && git clone --branch v0.9.5 --recursive https://github.com/neutrinolabs/xrdp.git \
    && cd /tmp/xrdp \
    && ./bootstrap \
    && ./configure \
    && make -j 4 \
    && make install \
    && cd /tmp/xrdp/sesman/chansrv/pulse \
    && sed -i "s/\/tmp\/pulseaudio\-10\.0/\/tmp\/pulseaudio\-8\.0/g" Makefile \
    && make \
    && cp *.so /usr/lib/pulse-8.0/modules/

# Build xorgxrdp

WORKDIR /tmp
RUN apt-get -yy install xserver-xorg-dev \
    && git clone --branch v0.2.5 --recursive https://github.com/neutrinolabs/xorgxrdp.git \
    && cd /tmp/xorgxrdp \
    && ./bootstrap \
    && ./configure \
    && make -j 4 \
    && make install

# Clean 

WORKDIR /
RUN apt-get -yy remove xscreensaver \
    && apt-get -yy remove $BULD_DEPS \
    && apt-get -yy autoremove \
    && apt-get -yy autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Configure

ENV TZ=Asia/Shanghai LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && locale-gen zh_CN.UTF-8 \
    && dpkg-reconfigure locales \
    && update-locale LANG=zh_CN.UTF-8 \
    && systemd-machine-id-setup

ADD bin /usr/bin
ADD etc /etc
#ADD pulse /usr/lib/pulse-10.0/modules/
RUN mkdir /var/run/dbus \
    && cp /etc/X11/xrdp/xorg.conf /etc/X11 \
    #&& sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config \
    && sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini \
    && echo "xfce4-session" > /etc/skel/.Xclients \
    #&& echo "export LANG=zh_CN.UTF-8" >> /etc/skel/.bashrc \
    #&& echo "export LANGUAGE=zh_CN:zh" >> /etc/skel/.bashrc \
    #&& echo "export LC_ALL=zh_CN.UTF-8" >> /etc/skel/.bashrc \
    && cp -r /etc/ssh /ssh_orig \
    && rm -rf /etc/ssh/* \
    && rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem \
    && useradd -m -d /home/guest -p guest guest -g users --groups adm,sudo \
    && echo 'guest:docker' | chpasswd \
    && chsh -s /bin/zsh guest

# Docker config

VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
