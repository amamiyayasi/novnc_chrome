FROM ubuntu:18.04

RUN set -xe          \
    && echo '#!/bin/sh' > /usr/sbin/policy-rc.d         \
    && echo 'exit 101' >> /usr/sbin/policy-rc.d         \
    && chmod +x /usr/sbin/policy-rc.d           \
    && dpkg-divert --local --rename --add /sbin/initctl         \
    && cp -a /usr/sbin/policy-rc.d /sbin/initctl        \
    && sed -i 's/^exit.*/exit 0/' /sbin/initctl                 \
    && echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup                 \
    && echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean       \
    && echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean  \
    && echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean          \
    && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages              \
    && echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes           \
    && echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests

RUN rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/systemd \
    && echo 'docker' > /run/systemd/container
CMD ["/bin/bash"]
ENV HOME=/root
#ENV DEBIAN_FRONTEND=noninteractive
#ENV LC_ALL=C.UTF-8
#ENV LANG=zh_CN.UTF-8
#ENV LANGUAGE=zh_CN.UTF-8
ENV TZ=Asia/Shanghai
#ENV SCREEN_RESOLUTION=1280x900

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

RUN sed -i "s@http://deb.debian.org@http://mirrors.aliyun.com@g" /etc/apt/sources.list && rm -Rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y install       xvfb    x11vnc  supervisor      fluxbox         git-core        git     ttf-wqy-microhei        ttf-wqy-zenhei  xfonts-wqy      wget    gnupg  unzip  fcitx-bin  fcitx-table  fcitx-pinyin


#
# 設定輸入法預設切換熱鍵 SHIFT-SPACE
#
RUN mkdir -p /root/.config/fcitx && \
	echo [Hotkey] > /root/.config/fcitx/config && \
	echo TriggerKey=SHIFT_SPACE >> /root/.config/fcitx/config \
	echo SwitchKey=Disabled >> /root/.config/fcitx/config \
	echo IMSwitchKey=False >> /root/.config/fcitx/config
#http://dl.google.com/linux/chrome/deb/
#https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#https://dl.google.com/linux/direct/google-chrome-stable_current_i386.deb
RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    &&  wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    &&  apt-get update \
    &&  apt-get install google-chrome-stable -y \
    &&  apt-get install -fy

RUN apt-get autoclean
WORKDIR /root
RUN git clone https://github.com/novnc/noVNC.git \
    && ln -s /root/noVNC/vnc_auto.html /root/noVNC/index.html


##==============================
## Locale and encoding settings
##==============================
## TODO: Allow to change instance language OS and Browser level
##  see if this helps: https://github.com/rogaha/docker-desktop/blob/68d7ca9df47b98f3ba58184c951e49098024dc24/Dockerfile#L57
#ENV LANG_WHICH en
#ENV LANG_WHERE US
#ENV ENCODING UTF-8
#ENV LANGUAGE ${LANG_WHICH}_${LANG_WHERE}.${ENCODING}
#ENV LANG ${LANGUAGE}
#RUN apt -qqy update \
#  && apt -qqy --no-install-recommends install \
#    language-pack-en \
#    tzdata \
#    locales \
#  && locale-gen ${LANGUAGE} \
#  && dpkg-reconfigure --frontend noninteractive locales \
#  && apt -qyy autoremove \
#  && rm -rf /var/lib/apt/lists/* \
#  && apt -qyy clean

#==============================
# Java8 - OpenJDK JRE headless
# Minimal runtime used for executing non GUI Java programs
#==============================
# Regarding urandom see
#  http://stackoverflow.com/q/26021181/511069
#  https://github.com/SeleniumHQ/docker-selenium/issues/14#issuecomment-67414070
RUN apt -qqy update \
  && apt -qqy install \
    openjdk-8-jre-headless \
  && sed -i '/securerandom.source=/ s|/dev/u?random|/dev/./urandom|g' \
       /etc/java-*/security/java.security \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean


#=================
# Selenium latest
#=================
ARG SEL_DIRECTORY="3.14"
ENV SEL_VER="3.141.59"

RUN wget -nv "https://github.com/dosel/selenium/releases/download/selenium-3.141.59-patch-d47e74d6f2/selenium.jar" \
  && ln -s "selenium.jar" \
           "selenium-server-standalone-${SEL_VER}.jar" \
  && ln -s "selenium.jar" \
           "selenium-server-standalone-3.jar"

LABEL selenium_version "${SEL_VER}"

#===============
# Google Chrome
#===============
#  https://www.google.de/linuxrepositories/
ARG EXPECTED_CHROME_VERSION="78.0.3904.97"
ENV CHROME_URL="https://dl.google.com/linux/direct" \
    CHROME_BASE_DEB_PATH="/root/chrome-deb/google-chrome" \
    GREP_ONLY_NUMS_VER="[0-9.]{2,20}"

LABEL selenium_chrome_version "${EXPECTED_CHROME_VERSION}"

#RUN apt -qqy update \
#  && mkdir -p /root/chrome-deb \
##  && wget -nv "${CHROME_URL}/google-chrome-stable_current_amd64.deb" \
#  && wget -nv "http://www.slimjetbrowser.com/chrome/files/78.0.3904.97/google-chrome-stable_current_amd64.deb" \
#          -O "/root/chrome-deb/google-chrome-stable_current_amd64.deb" \
#  && apt -qyy --no-install-recommends install \
#        "${CHROME_BASE_DEB_PATH}-stable_current_amd64.deb" \
#  && rm "${CHROME_BASE_DEB_PATH}-stable_current_amd64.deb" \
#  && rm -rf /root/chrome-deb \
#  && apt -qyy autoremove \
#  && rm -rf /var/lib/apt/lists/* \
#  && apt -qyy clean \
#  && export CH_STABLE_VER=$(/usr/bin/google-chrome-stable --version | grep -iEo "${GREP_ONLY_NUMS_VER}") \
#  && echo "CH_STABLE_VER:'${CH_STABLE_VER}' vs EXPECTED_CHROME_VERSION:'${EXPECTED_CHROME_VERSION}'" \
#  && [ "${CH_STABLE_VER}" = "${EXPECTED_CHROME_VERSION}" ] || fail

# We have a wrapper for /opt/google/chrome/google-chrome
#RUN mv /opt/google/chrome/google-chrome /opt/google/chrome/google-chrome-base
#COPY selenium-node-chrome/opt /opt
#COPY lib/* /usr/lib/

# Use a custom wallpaper for Fluxbox
#COPY images/wallpaper-dosel.png /usr/share/images/fluxbox/ubuntu-light.png
#COPY images/wallpaper-zalenium.png /usr/share/images/fluxbox/
#RUN chmod 777 /usr/share/images/fluxbox


#==================
# Chrome webdriver
#==================
# How to get cpu arch dynamically: $(lscpu | grep Architecture | sed "s/^.*_//")
ARG CHROME_DRIVER_VERSION="78.0.3904.70"
ENV CHROME_DRIVER_BASE="chromedriver.storage.googleapis.com" \
    CPU_ARCH="64"
ENV CHROME_DRIVER_FILE="chromedriver_linux${CPU_ARCH}.zip"
ENV CHROME_DRIVER_URL="https://${CHROME_DRIVER_BASE}/${CHROME_DRIVER_VERSION}/${CHROME_DRIVER_FILE}"
# Gets latest chrome driver version. Or you can hard-code it, e.g. 2.15
RUN  wget -nv -O chromedriver_linux${CPU_ARCH}.zip ${CHROME_DRIVER_URL}

RUN unzip chromedriver_linux${CPU_ARCH}.zip
RUN rm chromedriver_linux${CPU_ARCH}.zip \
  && mv chromedriver \
        chromedriver-${CHROME_DRIVER_VERSION} \
  && chmod 755 chromedriver-${CHROME_DRIVER_VERSION} \
  && ln -s chromedriver-${CHROME_DRIVER_VERSION} \
           chromedriver \
  && ln -s /root/chromedriver /usr/bin


RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    libtool \
    libffi-dev \
    git \
    libssl-dev \
    xorg-dev \
    libvncserver-dev \
    dbus-x11


# download  source code
RUN cd /root && mkdir src && cd src && git clone https://github.com/LibVNC/x11vnc

# compile and install , default install path /usr/local/bin/x11vnc
RUN apt-get remove -y x11vnc \
    && cd /root/src/x11vnc \
    && autoreconf -fiv \
    && ./configure \
    && make \
    && make install


ENV \
	# 時區
	TZ=Asia/Shanghai \
	# 系統語系
	LANG=zh_CN.UTF-8 \
	LANGUAGE=zh_CN \
	LC_ALL=zh_CN.UTF-8 \
	# 輸入法
	XMODIFIERS="@im=fcitx" \
	GTK_IM_MODULE=fcitx \
	QT_IM_MODULE=fcitx \
	#
	DISPLAY=:0 \
	SCREEN_RESOLUTION=1280x900


COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV DISPLAY=:0
EXPOSE 5900
EXPOSE 8083
EXPOSE 8080

VOLUME ["/cfg"]
CMD ["/usr/bin/supervisord"]


#docker run -d --name firefox -p 8083:8083 -p 5900:5900 -p 4444:4444 oldiy/chrome-novnc:latest

#docker run -d -p 8083:8083 -p 5900:5900 -p 8080:8080 demo
#docker run -d  -p 28083:8083 -p 25900:5900 -p 28080:8080 novnc
#docker run -d -p 5900:5900  -p 5800:5800 docker.io/raykuo/chrome-jdownloader2
#docker run  -e LANG=zh_CN -e LANGUAGE=zh_CN -e LC_ALL=zh_CN -p 5900:5900  -p 5800:5800 docker.io/raykuo/chrome-jdownloader2
#/usr/bin/x11vnc -nobell
#/usr/local/bin/x11vnc
#/usr/bin/x11vnc
#docker run -d -p 8083:8083 -p 5900:5900 oldiy/chrome-novnc:latest
