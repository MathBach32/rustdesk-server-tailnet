# hbbs et hbbr 1.1.16 officiels, plus un seul correctif : patches/1.1.16-initiator-networks.patch.
# Même construction que l'image classique officielle (rustdesk/rustdesk-server) : binaires statiques
# musl, Rust 1.90 comme la CI amont, image finale vide (FROM scratch).
#
#   docker build --network host -t rustdesk-server-tailnet:1.1.16 .
#
# Sources figées par commit : étiquette 1.1.16 et son sous-module hbb_common.
FROM rust:1.90-alpine AS construction
RUN apk add --no-cache git musl-dev build-base perl pkgconf openssl-dev openssl-libs-static
ENV OPENSSL_STATIC=1
WORKDIR /src
RUN git init -q rustdesk-server \
    && cd rustdesk-server \
    && git fetch -q --depth 1 https://github.com/rustdesk/rustdesk-server.git 73523b31cfd25d77dee862e6fc9f5e1fb5e485ef \
    && git checkout -q FETCH_HEAD \
    && git init -q libs/hbb_common \
    && git -C libs/hbb_common fetch -q --depth 1 https://github.com/rustdesk/hbb_common.git 83419b6549636ee39dacef7776c473f5802e08d6 \
    && git -C libs/hbb_common checkout -q FETCH_HEAD
COPY patches/1.1.16-initiator-networks.patch /src/
RUN cd rustdesk-server && git apply --verbose /src/1.1.16-initiator-networks.patch
RUN cd rustdesk-server \
    && cargo build --release --locked --all-features --target x86_64-unknown-linux-musl --bin hbbs --bin hbbr \
    && cp target/x86_64-unknown-linux-musl/release/hbbs target/x86_64-unknown-linux-musl/release/hbbr /src/

FROM scratch
COPY --from=construction /src/hbbs /usr/bin/hbbs
COPY --from=construction /src/hbbr /usr/bin/hbbr
WORKDIR /root
ENV HOME=/root
