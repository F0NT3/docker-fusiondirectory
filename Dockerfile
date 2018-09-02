FROM lanycrost/alpine:3.8

LABEL maintainer="Khachatur Ashotyan (lanycrost)"
LABEL version="0.1"
LABEL description="FusionDirectory LDAP Manager w/S6 Overlay, Nginx, PHP7 based on Alpine."

ENV ARGONAUT_VERSION=1.2 \
    FUSIONDIRECTORY_VERSION=1.2.1 \
    SCHEMA2LDIF_VERSION=1.3 \
    SMARTY_VERSION=3.1.31 \
    SMARTYGETTEXT_VERSION=1.5.1 \
    INSTANCE=default \
    PHP_ENABLE_GETTEXT=TRUE \
    PHP_ENABLE_IMAGICK=TRUE \
    PHP_ENABLE_IMAP=TRUE

# Dependency Installation
RUN set -x && \
  echo 'http://dl-4.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
  apk update && \
  apk add \
    apache2-utils \
    ca-certificates \
    openssl \
    nginx \
    php7 \
    php7-curl \
    php7-fpm \
    php7-gettext \
    php7-imap \
    php7-imagick \
    php7-ldap \
    php7-mbstring \
    php7-opcache \
    php7-openssl \
    php7-phar\
    php7-posix \
    php7-session && \
    rm -rf /var/cache/apk/*

# Nginx and PHP7 Setup
RUN set -x && \
  sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php7/php.ini && \
  sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/www:\/bin\/bash/g" /etc/passwd && \
  sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/www:\/bin\/bash/g" /etc/passwd- && \
  ln -s /sbin/php-fpm7 /sbin/php-fpm

# Build FusionDirectory Dependencies
RUN set -x && \
  apk update && \
  apk add --no-cache --virtual \
    build-deps \
    coreutils \
    build-base \
    make \
    perl-dev

# Run Dependencies Installation
RUN set -x && \
  apk add --virtual run-deps \
    gettext \
    gettext-lang \
    openldap \
    perl-config-inifiles \
    perl-datetime \
    perl-ldap \
    perl-mime-base64 \
    perl-crypt-cbc \
    perl-file-copy-recursive \
    perl-io-socket-ssl \
    perl-json \
    perl-net-ldap \
    perl-path-class \
    perl-term-readkey \
    perl-xml-twig

# Install Perl Dependencies that aren't available as packages
RUN set -x && \
  ln -s /usr/bin/perl /usr/local/bin/perl && \
  curl -L http://cpanmin.us -o /usr/bin/cpanm && \
  chmod +x /usr/bin/cpanm && \
  cpanm -n \
  App::Daemon \
  Archive::Extract \
  HTTP::Daemon \
  JSON::Any \
  JSON::RPC \
  Log::Handler \
  Mail::Sendmail \
  Module::Pluggable \
  POE \
  POE::Component::Schedule \
  POE::Component::Server::SimpleHTTP \
  POE::Component::Pool::Thread \
  POE::Component::SSLify \
  XML::SAX::Expat && \
  cp -R /usr/local/share/perl5/site_perl/* /usr/share/perl5/vendor_perl/

# Cleanup
RUN set -x && \
  rm -rf /root/.cpanm && \
  apk del build-deps && \
  rm -rf /tmp/* /var/cache/apk/*

# Install Smarty3
RUN set -x && \
  mkdir -p /usr/src/smarty /usr/src/smarty-gettext /usr/share/php/smarty3 && \
  curl https://codeload.github.com/smarty-php/smarty/tar.gz/v${SMARTY_VERSION} | tar xvfz - --strip 1 -C /usr/src/smarty && \
  cp -r /usr/src/smarty/libs/* /usr/share/php/smarty3 && \
  ln -s /usr/share/php/smarty3/Smarty.class.php /usr/share/php/smarty3/smarty.class.php && \
  curl https://codeload.github.com/smarty-gettext/smarty-gettext/tar.gz/${SMARTYGETTEXT_VERSION} | tar xvfz - --strip 1 -C /usr/src/smarty-gettext && \
  mkdir -p /usr/share/php/smarty3/plugins && \
  cp -R /usr/src/smarty-gettext/block.t.php /usr/share/php/smarty3/plugins/ && \
  cp -R /usr/src/smarty-gettext/tsmarty2c.php /usr/sbin && \
  chmod 750 /usr/sbin/tsmarty2c.php

# Install Schema2LDIF
RUN set -x && \
  curl https://codeload.github.com/fusiondirectory/schema2ldif/tar.gz/${SCHEMA2LDIF_VERSION} | tar xvfz - --strip 1 -C /usr && \
  rm -rf /usr/CHANGELOG && \
  rm -rf /usr/LICENSE

# Install Argonaut
RUN set -x && \
  mkdir -p /usr/src/argonaut /etc/argonaut && \
  curl https://codeload.github.com/fusiondirectory/argonaut/tar.gz/argonaut-${ARGONAUT_VERSION} | tar xvfz - --strip 1 -C /usr/src/argonaut && \
  chmod +x /usr/src/argonaut/*/bin/* && \
  cp -R /usr/src/argonaut/argonaut-common/Argonaut /usr/share/perl5/vendor_perl/ && \
  cp -R /usr/src/argonaut/argonaut-common/XML /usr/share/perl5/vendor_perl/ && \
  cp -R /usr/src/argonaut/argonaut-common/argonaut.conf /etc/argonaut && \
  cp -R /usr/src/argonaut/argonaut-fusiondirectory/bin/* /usr/sbin && \
  cp -R /usr/src/argonaut/argonaut-fusioninventory/bin/* /usr/sbin && \
  cp -R /usr/src/argonaut/argonaut-server/bin/argonaut-server /usr/sbin && \
  cp -R /usr/src/argonaut/argonaut-server/Argonaut /usr/share/perl5/vendor_perl/ && \
  cp -R /usr/src/argonaut/*/Argonaut/ /usr/share/perl5/vendor_perl

# Install FusionDirectory
RUN set -x && \
  mkdir -p /usr/src/fusiondirectory /assets/fusiondirectory-plugins && \
  curl https://codeload.github.com/fusiondirectory/fusiondirectory/tar.gz/fusiondirectory-${FUSIONDIRECTORY_VERSION} | tar xvfz - --strip 1 -C /usr/src/fusiondirectory && \
  curl https://codeload.github.com/fusiondirectory/fusiondirectory-plugins/tar.gz/fusiondirectory-${FUSIONDIRECTORY_VERSION} | tar xvfz - --strip 1 -C /assets/fusiondirectory-plugins

# Configure FusionDirectory
RUN set -x && \
  mkdir -p /usr/src/javascript && \
  cd /usr/src/javascript && \
  curl -O http://ajax.googleapis.com/ajax/libs/prototype/1.7.1.0/prototype.js && \
  curl -O http://script.aculo.us/dist/scriptaculous-js-1.9.0.zip && \
  unzip -d . scriptaculous-js-1.9.0.zip && \
  cp -R prototype.js /usr/src/fusiondirectory/html/include && \
  cp -R scriptaculous-js-1.9.0/src/scriptaculous.js /usr/src/fusiondirectory/html/include && \
  cp -R scriptaculous-js-1.9.0/src/builder.js /usr/src/fusiondirectory/html/include && \
  cp -R scriptaculous-js-1.9.0/src/controls.js /usr/src/fusiondirectory/html/include && \
  cp -R scriptaculous-js-1.9.0/src/dragdrop.js /usr/src/fusiondirectory/html/include && \
  cp -R scriptaculous-js-1.9.0/src/effects.js /usr/src/fusiondirectory/html/include && \
  # Patch 1.3 Files for Groups of Groups Display
  cd /usr/src/fusiondirectory/plugins/admin/groups/ && \
  rm -rf class_groupManagement.inc group-filter.xml && \
  wget https://gitlab.fusiondirectory.org/fusiondirectory/fd/raw/754871d5b0edb9ce0d427d1897083bea6a8ef63a/plugins/admin/groups/class_groupManagement.inc && \
  wget https://gitlab.fusiondirectory.org/fusiondirectory/fd/raw/1.3-dev/plugins/admin/groups/group-filter.xml && \
  chmod 750 /usr/src/fusiondirectory/contrib/bin/* && \
  cp -R /usr/src/fusiondirectory/contrib/bin/* /usr/sbin/ && \
  cp -R /usr/src/fusiondirectory/contrib/smarty/plugins/* /usr/share/php/smarty3/plugins/ && \
  mkdir -p /var/spool/fusiondirectory/ && \
  mkdir -p /var/cache/fusiondirectory/ && \
  mkdir -p /var/cache/fusiondirectory/fai && \
  mkdir -p /var/cache/fusiondirectory/include && \
  mkdir -p /var/cache/fusiondirectory/locale && \
  mkdir -p /var/cache/fusiondirectory/template && \
  mkdir -p /var/cache/fusiondirectory/tmp && \
  mkdir -p /etc/fusiondirectory && \
  mkdir -p /www && \
  cp -R /usr/src/fusiondirectory/contrib/fusiondirectory.conf /var/cache/fusiondirectory/template/fusiondirectory.conf && \
  cp -R /usr/src/fusiondirectory /www/fusiondirectory && \
  fusiondirectory-setup --set-fd_home="/www/fusiondirectory" --write-vars && \
  fusiondirectory-setup --set-fd_home="/www/fusiondirectory" --set-fd_smarty_dir="/usr/share/php/smarty3/Smarty.class.php" --write-vars && \
  touch /etc/debian_version && \
  yes Yes | fusiondirectory-setup --set-fd_home="/www/fusiondirectory" --check-directories --update-cache && \
  fusiondirectory-setup --set-fd_home="/www/fusiondirectory" --update-locales --update-cache

# PHP Setup
RUN set -x && \
  sed -i -e "s/expose_php = On/expose_php = Off/g" /etc/php7/php.ini

# Cleanup
RUN set -x && \
  rm -rf /usr/src/*

# Add Assets
ADD install /

# S6 sctipts permissions
RUN set -x && \
  chmod -R u+x /etc/s6 && \
  chmod -R u+x /etc/cont-init.d

EXPOSE 80 443
