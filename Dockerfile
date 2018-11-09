FROM alpine:3.8
MAINTAINER Gabriel Ionescu <gabi.ionescu+docker@protonmail.com>

# ARGS
ARG SSH_USERNAME
ARG SSH_PASSWORD
ARG SLACK_ENDPOINT

# INSTALL SSH & CURL
RUN apk add --no-cache openssh-server-pam curl

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
 && sed -ri 's/^#?PrintMotd\s+.*/PrintMotd no/' /etc/ssh/sshd_config

# REMOVE STUFF
RUN rm /bin/su

# PORT
EXPOSE 22

# LAUNCH SSH DAEMON
CMD ["/usr/sbin/sshd", "-D", "-e"]
