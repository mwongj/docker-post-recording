﻿# chacawaca/post-recording

FROM ubuntu:20.04 AS builder
WORKDIR /tmp
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends \
      coreutils findutils expect tcl8.6 \
      mediainfo libfreetype6 libutf8proc2 \
      libtesseract4 libpng16-16 expat \
      libva-drm2 i965-va-driver \
      libxcb-shape0 libssl1.1 -y && \
      useradd -u 911 -U -d /config -s /bin/false abc && \
      usermod -G users abc && \
      mkdir /config /output && \
      apt-get install -y python3 git build-essential libargtable2-dev autoconf \
      libtool-bin libsdl1.2-dev libswscale-dev libavutil-dev libavformat-dev libavcodec-dev nginx && \
      echo "daemon off;" >> /etc/nginx/nginx.conf

# Clone Comskip
RUN cd /opt && \
    git clone https://github.com/erikkaashoek/Comskip.git && \
    cd Comskip && \
    ./autogen.sh && \
    ./configure && \
    make

# Clone Comchap
RUN cd /opt && \
    git clone https://github.com/BrettSheleski/comchap.git && \
    cd comchap && \
    make

FROM ubuntu:20.04 AS stage1

RUN apt-get update \
   && apt-get install -y --no-install-recommends curl \
   && apt-get autoremove -y \
   && apt-get purge -y --auto-remove \
   && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/Comskip/comskip /usr/local/bin
COPY --from=builder /opt/comchap /usr/local/bin

# Copy ccextractor
COPY --from=gizmotronic/ccextractor /usr/local/bin /usr/local/bin
# Copy ffmpeg
COPY --from=chacawaca/ffmpeg /usr/local/ /usr/local/
# Copy S6-Overlay
#COPY --from=djaydev/baseimage-s6overlay:amd64 /tmp/ /
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.1/s6-overlay-amd64-installer /tmp/
RUN chmod +x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer /
# Copy script for Intel iGPU permissions
COPY --from=linuxserver/plex /etc/s6-overlay/s6-rc.d/init-plex-gid-video/run /etc/cont-init.d/50-gid-video

# Copy the start scripts.
COPY rootfs/ /

ENV SUBTITLES=0 \
    DELETE_TS=1 \
    SOURCE_EXT=ts \
    PUID=99 \
    PGID=100 \
    UMASK=000 \
    CONVERSION_FORMAT=mp4 \
    POST_PROCESS=comchap \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    SOURCE_STABLE_TIME=10 \
    SOURCE_MIN_DURATION=10 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    COMSKIP_FLAGS=""

ENTRYPOINT ["/init"]
