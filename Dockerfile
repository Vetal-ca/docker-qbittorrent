FROM  alpine:3.13 AS build

# https://github.com/qbittorrent/qBittorrent/wiki/Compilation:-Alpine-Linux

ENV QBITTORRENT_TAG="release-4.3.9"
RUN apk update && apk add --no-cache git gcc g++ pkgconfig qt5-qtbase-dev qt5-qtsvg-dev boost-dev \
    cmake build-base qt5-qttools-dev

WORKDIR /tmp

# https://github.com/google/oss-fuzz/blob/master/projects/libtorrent/Dockerfile

RUN git clone --recurse-submodules https://github.com/qbittorrent/qBittorrent.git &&\
    git clone --recurse-submodules https://github.com/arvidn/libtorrent.git &&\
    git clone --depth 1 --single-branch --branch boost-1.76.0 --recurse-submodules https://github.com/boostorg/boost.git &&\
    cd libtorrent/ && mkdir build && cd build &&\
    cmake .. &&\
    make && make install &&\
    cd /tmp/qBittorrent &&\
    git checkout ${QBITTORRENT_TAG} &&\
    git config pull.rebase true &&\
    ./configure PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig --disable-gui --disable-stacktrace &&\
    make && make install

FROM alpine:3.13

ENV HOME="/home/qbittorrent"

RUN apk update && apk add --no-cache libgcc libstdc++ boost qt5-qtbase dumb-init su-exec

COPY --from=build /usr/local/share/man/man1/qbittorrent-nox.1 /usr/local/share/man/man1/qbittorrent-nox.1
COPY --from=build /usr/local/lib64/libtorrent-rasterbar.so.2.0 /usr/lib/libtorrent-rasterbar.so.2.0
COPY --from=build /usr/local/bin/qbittorrent-nox /usr/local/bin/qbittorrent-nox

RUN adduser -S -D -u 520 -g 520 -s /sbin/nologin qbittorrent \
    # Create symbolic links to simplify mounting
 && mkdir -p "${HOME}/.config/qBittorrent" \
 && mkdir -p "${HOME}/.local/share/qBittorrent" \
    # Check it works
 && su qbittorrent -s /bin/sh -c 'qbittorrent-nox -v'

# Default configuration file.
COPY qBittorrent.conf /default/qBittorrent.conf
COPY entrypoint.sh /

VOLUME ["/home/qbittorrent"]

USER qbittorrent

EXPOSE 8080 6881

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
CMD ["qbittorrent-nox"]