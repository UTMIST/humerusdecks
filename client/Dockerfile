FROM node:14-alpine AS build

WORKDIR /md

RUN ["apk", "add", "--no-cache", "python", "make", "g++", "openjdk8-jre"]

ARG VERSION=dev
ENV MD_VERSION $VERSION

COPY ["./package.json", "./package-lock.json", "./"]
RUN ["npm", "ci"]

COPY ["./tsconfig.json", "postcss.config.js", "./webpack.config.js", "./elm.json", "./"]
COPY ["./src", "./src"]
COPY ["./assets", "./assets"]
RUN ["npm", "run", "build"]

FROM nginx:mainline-alpine

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=dev

EXPOSE 8080

LABEL maintainer="brianchen.chen@mail.utoronto.ca"
LABEL org.label-schema.description="The web client for humerus bot"
LABEL org.label-schema.url="https://github.com/UTMIST/massivedecks"
LABEL org.label-schema.vcs-url="https://github.com/UTMIST/massivedecks"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.version=$VERSION

COPY --from=build ["/md/dist", "/usr/share/nginx/html/"]
<<<<<<< HEAD
=======



>>>>>>> b25dad87a5ee0dc806c312079ee68a012e5d7866
COPY ["./nginx.conf", "/etc/nginx/nginx.conf"]
