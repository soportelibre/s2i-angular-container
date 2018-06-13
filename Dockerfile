FROM centos/s2i-base-centos7

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

EXPOSE 8080

# Add $HOME/node_modules/.bin to the $PATH, allowing user to make npm scripts
# available on the CLI without using npm's --global installation mode
# This image will be initialized with "npm run $NPM_RUN"
# See https://docs.npmjs.com/misc/scripts, and your repo's package.json
# file for possible values of NPM_RUN
# Description
# Environment:
# * $NPM_RUN - Select an alternate / custom runtime mode, defined in your package.json files' scripts section (default: npm run "start").
# Expose ports:
# * 8080 - Unprivileged port used by nodejs application

ENV NODEJS_VERSION=8 \
    NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH

ENV SUMMARY="Platform for building and running Node.js $NODEJS_VERSION applications" \
    DESCRIPTION="Node.js $NODEJS_VERSION available as container is a base platform for \
building and running various Node.js $NODEJS_VERSION applications and frameworks. \
Node.js is a platform built on Chrome's JavaScript runtime for easily building \
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model \
that makes it lightweight and efficient, perfect for data-intensive real-time applications \
that run across distributed devices."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Node.js $NODEJS_VERSION" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,$NAME,$NAME$NODEJS_VERSION" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i" \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="${APP_ROOT}/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858"\
      com.redhat.component="rh-$NAME$NODEJS_VERSION-docker" \
      name="centos/$NAME-$NODEJS_VERSION-centos7" \
      version="$NODEJS_VERSION" \
      maintainer="Ricardo Arguello <ricardo.arguello@soportelibre.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container" \
      usage="s2i build <SOURCE-REPOSITORY> centos/$NAME-$NODEJS_VERSION-centos7:latest <APP-NAME>"

RUN yum install -y centos-release-scl-rh && \
    ( [ "rh-${NAME}${NODEJS_VERSION}" != "${NODEJS_SCL}" ] && yum remove -y ${NODEJS_SCL}\* || : ) && \
    INSTALL_PKGS="rh-nodejs8 rh-nodejs8-npm rh-nodejs8-nodejs-nodemon nss_wrapper httpd24" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image, including help file.
COPY ./root/ /

ENV HTTPD_CONF_PATH=/opt/rh/httpd24/root/etc/httpd/conf

RUN sed -i -e 's/^Listen 80/Listen 0.0.0.0:8080/' ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e "s/^User apache/User default/" ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e "s/^Group apache/Group root/" ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e "s%^DocumentRoot \"/opt/rh/httpd24/root/var/www/html\"%DocumentRoot \"${APP_ROOT}/src/dist\"%" ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e "s%^<Directory \"/opt/rh/httpd24/root/var/www/html\"%<Directory \"${APP_ROOT}/src/dist\"%" ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e '151s%AllowOverride None%AllowOverride All%' ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e 's%^ErrorLog "logs/error_log"%ErrorLog "/tmp/error_log"%' ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -e 's%CustomLog "logs/access_log"%CustomLog "/tmp/access_log"%' ${HTTPD_CONF_PATH}/httpd.conf && \
    sed -i -r " s!^(\s*CustomLog)\s+\S+!\1 |/usr/bin/cat!g; s!^(\s*ErrorLog)\s+\S+!\1 |/usr/bin/cat!g;" ${HTTPD_CONF_PATH}/httpd.conf && \
    head -n151 ${HTTPD_CONF_PATH}/httpd.conf | tail -n1 | grep "AllowOverride All" || exit

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} && \
    chmod -R a+rwx /opt/rh/httpd24/root/var/run/httpd && \
    chmod -R a+rwx /opt/rh/httpd24/root/etc/httpd/logs && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
