FROM jboss/keycloak:9.0.2

LABEL maintainer="Guilherme Albuquerque "heisendumb""

COPY ./default.cli /opt/jboss/tools/cli/jgroups/discovery/default.cli

COPY ./themes /opt/jboss/keycloak/themes/

USER root 

RUN chown -R jboss:root /opt/jboss/keycloak/themes/* \
    && sed -i 's/"$JAVA_OPTS -Djboss.modules.system.pkgs=$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true"/"$JAVA_OPTS -Djboss.modules.system.pkgs=$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true -Dkeycloak.profile.feature.scripts=enabled -Dkeycloak.profile.feature.admin_fine_grained_authz=enabled -Dkeycloak.profile.feature.token_exchange=enabled -Dkeycloak.profile.feature.authz_drools_policy=enabled"/g' /opt/jboss/keycloak/bin/standalone.conf
