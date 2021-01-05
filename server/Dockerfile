
FROM node:14-alpine AS build

WORKDIR /md

RUN apk --no-cache --virtual build-dependencies add \
    python \
    make \
    g++ \
    bash \
    gcc \
    && npm install \
    && apk del build-dependencies

ENV PYTHONUNBUFFERED=1 
RUN apk add --update --no-cache python3 postgresql-dev g++ make bash 
RUN ln -sf python3 /usr/bin/python
RUN pip3 install --no-cache --upgrade pip setuptools


COPY ["./package.json", "./package-lock.json", "./"]
RUN ["npm", "ci"]

COPY ["./src", "./src"]
COPY ["./tsconfig.json", "./config.json5", "./"]
RUN ["npm", "run", "build"]

FROM node:14-alpine

ENV PYTHONUNBUFFERED=1 
RUN apk add --update --no-cache python3 postgresql-dev g++ make bash 
RUN ln -sf python3 /usr/bin/python
RUN pip3 install --no-cache --upgrade pip setuptools


ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=dev

ENV MD_VERSION $VERSION

LABEL maintainer="brianchen.chen@mail.utoronto.ca"
LABEL org.label-schema.description="Web server for humerus bot."
LABEL org.label-schema.url="https://github.com/UTMIST/Humerus"
LABEL org.label-schema.vcs-url="https://github.com/UTMIST/Humerus"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.version=$VERSION

WORKDIR /md

COPY ["./package.json", "./package-lock.json", "./"]
RUN ["npm", "ci", "--only=production"]

COPY ["./config.json5", "./"]
COPY ["./decks", "./decks"]
COPY --from=build ["/md/dist", "./"]

EXPOSE 8081
USER node
CMD ["node", "--es-module-specifier-resolution=node", "./index.js"]
