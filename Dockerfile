FROM alpine:3.8
MAINTAINER Gabriel Ionescu <gabi.ionescu+docker@protonmail.com>

# ARGS
ARG SSH_HOSTNAME
ARG SSH_USERNAME
ARG SSH_PASSWORD
ARG SLACK_ENDPOINT

# INSTALL SSH, GOOGLE AUTH & CURL
RUN apk add --no-cache openssh-server-pam google-authenticator curl

# SET RANDOM ROOT PASSWORD
RUN echo "root:$(echo "`date`-`hostname`" | md5sum -t | awk -F' ' '{print $1}')" | chpasswd

# CREATE USER
RUN adduser -D $SSH_USERNAME \
 && echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd

# CREATE USER SSH FILES
RUN mkdir /home/$SSH_USERNAME/.ssh \
 && chown $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME/.ssh \
 && chmod 0700 /home/$SSH_USERNAME/.ssh \
 && touch /home/$SSH_USERNAME/.ssh/authorized_keys \
 && chown $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME/.ssh/authorized_keys

# CREATE KEYS
RUN /usr/bin/ssh-keygen -A

# SET ALERT ON AUTH
RUN echo -e "\nsession optional pam_exec.so seteuid /etc/ssh/notifier.sh" >> /etc/pam.d/sshd

# MAKE USER EXIT ON TTY LOGIN
RUN echo "exit" > /etc/profile

# BLANK MOTD
RUN echo "" > /etc/motd

# ADD ALERT SCRIPT
COPY notifier.sh /tmp/notifier.sh
RUN echo -e "#!/bin/sh\n\nSLACK_ENDPOINT=\"$SLACK_ENDPOINT\"\n" > /etc/ssh/notifier.sh \
 && cat /tmp/notifier.sh >> /etc/ssh/notifier.sh \
 && rm /tmp/notifier.sh \
 && chmod 444 /etc/ssh/notifier.sh \
 && chmod +x /etc/ssh/notifier.sh

# SSH CONFIG
RUN sed -ri 's/^#?Port\s+.*/Port 22/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?PermitEmptyPasswords\s+.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?UsePAM\s+.*/UsePAM yes/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?AllowAgentForwarding\s+.*/AllowAgentForwarding yes/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?AllowTcpForwarding\s+.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?GatewayPorts\s+.*/GatewayPorts no/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?X11Forwarding\s+.*/X11Forwarding no/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?PermitTTY\s+.*/PermitTTY no/' /etc/ssh/sshd_config \
 && sed -ri 's/^#?PrintMotd\s+.*/PrintMotd no/' /etc/ssh/sshd_config \
 && echo -e "\nAllowUsers $SSH_USERNAME" >> /etc/ssh/sshd_config

# PAM - ALLOWED USERS
RUN echo "$SSH_USERNAME" > /etc/ssh/sshd.allow \
 && echo 'auth            required        pam_listfile.so item=user sense=allow file=/etc/ssh/sshd.allow onerr=fail' >> /etc/pam.d/base-auth

# PAM - LOCK ACCOUNTS FOR 10 MINUTES AFTER 2 FAILED LOGINS
RUN echo 'account         required        pam_tally2.so' >> /etc/pam.d/base-account \
 && echo 'auth            required        pam_tally2.so   file=/var/log/tallylog deny=2 even_deny_root unlock_time=600' >> /etc/pam.d/base-auth

# SETUP TWO FACTOR AUTH
RUN echo 'auth            required        pam_google_authenticator.so' >> /etc/pam.d/base-auth
USER $SSH_USERNAME
RUN echo -e "\n\n\n=====================[ TWO-FACTOR AUTHENTICATION ]====================\n\n\n" \
 && google-authenticator --time-based --disallow-reuse --rate-limit=3 --rate-time=30 --window-size=17 --label="$SSH_HOSTNAME" --issuer="SSH" --force \
 && echo -e "\n\n\n======================================================================\n\n\n"
USER root

# REMOVE SU
RUN rm /bin/su

# PORT
EXPOSE 22

# LAUNCH SSH DAEMON
CMD ["/usr/sbin/sshd", "-D", "-e"]
