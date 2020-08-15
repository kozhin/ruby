# Set initial image
FROM kozhin/node:latest

# Set maintainer and info for image
LABEL Description="This image contains Ruby language with NodeJS" \
      Vendor="CodedRed" \
      Version="1.2.1" \
      Maintainer="Konstantin Kozhin <https://github.com/kozhin>"

# Don't install gem documentation
RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

# Define arg variables
ARG RUBY_MAJOR
ARG RUBY_VERSION
ARG RUBY_CHECKSUM_SHA256

# Set env variables
ENV RUBY_MAJOR $RUBY_MAJOR
ENV RUBY_VERSION $RUBY_VERSION
ENV RUBY_DOWNLOAD_SHA256 $RUBY_CHECKSUM_SHA256

# some of ruby's build scripts are written in ruby
# we purge system ruby later to make sure our final image uses what we just built
# readline-dev vs libedit-dev: https://bugs.ruby-lang.org/issues/11869 and
# https://github.com/docker-library/ruby/issues/75
RUN set -ex \
  \
  && apk add --no-cache --virtual .ruby-builddeps \
    autoconf \
    bison \
    bzip2 \
    bzip2-dev \
    ca-certificates \
    coreutils \
    dpkg-dev dpkg \
    gcc \
    gdbm-dev \
    glib-dev \
    libc-dev \
    libffi-dev \
    libressl \
    libressl-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    make \
    ncurses-dev \
    patch \
    procps \
    readline-dev \
    ruby \
    tar \
    xz \
    yaml-dev \
    zlib-dev \
  \
  && wget -O ruby.tar.gz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.gz" \
  && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
  \
  && mkdir -p /usr/src/ruby \
  && tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.gz \
  \
  && cd /usr/src/ruby \
  \
# https://github.com/docker-library/ruby/issues/196
# https://bugs.ruby-lang.org/issues/14387#note-13 (patch source)
# https://bugs.ruby-lang.org/issues/14387#note-16
# ("Therefore ncopa's patch looks good for me in general." -- only breaks glibc which doesn't matter here)
  && wget -O 'thread-stack-fix.patch' 'https://bugs.ruby-lang.org/attachments/download/7081/0001-thread_pthread.c-make-get_main_stack-portable-on-lin.patch' \
  && echo '3ab628a51d92fdf0d2b5835e93564857aea73e0c1de00313864a94a6255cb645 *thread-stack-fix.patch' | sha256sum -c - \
  && patch -p1 -i thread-stack-fix.patch \
  && rm thread-stack-fix.patch \
  \
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
# warning: Insecure world writable dir
  && { \
    echo '#define ENABLE_PATH_CHECK 0'; \
    echo; \
    cat file.c; \
  } > file.c.new \
  && mv file.c.new file.c \
  \
  && autoconf \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
# the configure script does not detect isnan/isinf as macros
  && export ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
  && ./configure \
    --build="$gnuArch" \
    --disable-install-doc \
    --enable-shared \
  && make -j "$(nproc)" \
  && make install \
  \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && apk add --no-network --virtual .ruby-rundeps $runDeps \
    bzip2 \
    ca-certificates \
    libffi-dev \
    procps \
    yaml-dev \
    zlib-dev \
  && apk del --no-network .ruby-builddeps \
  && cd / \
  && rm -r /usr/src/ruby \
# rough smoke test
  && ruby --version && gem --version && bundle --version

# Install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"

# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
ENV PATH $GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"
# (BUNDLE_PATH = GEM_HOME, no need to mkdir/chown both)

CMD [ "irb" ]
