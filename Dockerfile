# build
FROM golang:1.14.7-alpine3.12 AS build
WORKDIR /go/src/${owner:-github.com/IzakMarais}/reporter
RUN apk update && apk add make git
ADD . .
RUN make build

# create image
FROM alpine:3.12
COPY util/texlive.profile /

# Pin a *fresh* CTAN mirror for both install-tl and tlmgr
ENV CTAN_REPO="https://ctan.math.illinois.edu/systems/texlive/tlnet"

RUN PACKAGES="wget perl-switch fontconfig fontconfig-dev" \
        && apk update \
        && apk add $PACKAGES \
        && apk add ca-certificates \
        && CTAN_REPO="$CTAN_REPO" wget -qO- \
          "https://github.com/yihui/tinytex/raw/main/tools/install-unx.sh" | \
          CTAN_REPO="$CTAN_REPO" sh -s - --admin --no-path \
        && { [ -d /root/.TinyTeX ] && mv /root/.TinyTeX /opt/TinyTeX || \
             { [ -d /opt/TinyTeX ] || { [ -d /usr/local/TinyTeX ] && ln -s /usr/local/TinyTeX /opt/TinyTeX; }; }; } \
        && /opt/TinyTeX/bin/*/tlmgr path add \
        && tlmgr path add \
        && chown -R root:adm /opt/TinyTeX \
        && chmod -R g+w /opt/TinyTeX \
        && chmod -R g+wx /opt/TinyTeX/bin \
        # Make tlmgr use the same pinned repo, then install needed packages
        && tlmgr option repository "$CTAN_REPO" \
        && tlmgr update --self \
        && tlmgr install epstopdf-pkg xstring titling fancyhdr inter greek-fontenc ly1 fontaxes cbfonts cbfonts-fd lh cyrillic cm-super babel-english hyphen-english babel-bulgarian hyphen-bulgarian\
        # Cleanup
        && apk del --purge -qq $PACKAGES \
        && apk del --purge -qq \
        && rm -rf /var/lib/apt/lists/*

COPY --from=build /go/bin/grafana-reporter /usr/local/bin
ENTRYPOINT [ "/usr/local/bin/grafana-reporter" ]