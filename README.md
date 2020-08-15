# Ruby image with Alpine Linux

> for Docker lightweight containers - image size is less than 60 Mb

## Building image

```en
docker build -t ruby .
```

## How to use

```en
# add to your Dockerfile
FROM <your docker registry URL>/ruby:latest
```

If you need Ruby with NodeJS, use special image:

```en
# add to your Dockerfile
FROM <your docker registry URL>/ruby:latest-nodejs
```

## Configuration

Update this line to install necessary version of Ruby.

```en
# Set env variables
ENV RUBY_MAJOR="2.7" RUBY_VERSION="2.7.1"
```
