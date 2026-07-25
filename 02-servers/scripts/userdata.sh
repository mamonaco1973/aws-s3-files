#!/bin/bash

set -euo pipefail

# Centralized user-data logging
LOG=/root/userdata.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "user-data start: $(date -Is)"

# ==============================================================================
# Base setup — Amazon Linux 2023 gateway
# ------------------------------------------------------------------------------
# On AL2023 the SSM agent and AWS CLI v2 are preinstalled, and amazon-efs-utils
# 3.x (which carries the mount.s3files helper) is available prebuilt in the
# default repos — so there is no on-boot source build.
# ==============================================================================

# SSM agent ships with AL2023; just make sure it is running.
systemctl enable --now amazon-ssm-agent

# AD membership, Samba, NFS client, and the S3 Files mount helper.
dnf -y install \
  realmd sssd sssd-tools adcli oddjob oddjob-mkhomedir \
  samba samba-common-tools samba-winbind samba-winbind-clients \
  sssd-winbind-idmap krb5-workstation authselect nfs-utils \
  amazon-efs-utils git jq nano vim less unzip
# Fail fast (ERR trap) if the S3 Files helper is somehow absent.
which mount.s3files

# SELinux to permissive — avoids Samba/NFS labeling denials in this lab.
setenforce 0 || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true

# ==============================================================================
# S3 Files mount
# ------------------------------------------------------------------------------
# The backing S3 bucket is presented as NFS v4.2. The mount helper resolves the
# in-VPC mount target from the file-system id, so no DNS/IP is needed. nofail
# keeps boot resilient if the target lags on startup. Homes are served from the
# EFS-backed serving tier, so read-your-writes and locking behave like EFS.
# ==============================================================================
mkdir -p /s3
echo "${s3files_fs_id}:/ /s3 s3files _netdev,nofail 0 0" >> /etc/fstab
systemctl daemon-reload
mount /s3

mkdir -p /s3/home /s3/data
echo "${s3files_fs_id}:/home /home s3files _netdev,nofail 0 0" >> /etc/fstab
systemctl daemon-reload
mount /home

# ==============================================================================
# Active Directory join
# ==============================================================================
secretValue=$(aws secretsmanager get-secret-value \
  --secret-id ${admin_secret} \
  --query SecretString \
  --output text)

admin_password=$(echo "$secretValue" | jq -r '.password')
admin_username=$(echo "$secretValue" | jq -r '.username' | sed 's/.*\\//')

echo -e "$admin_password" | realm join \
  --membership-software=samba \
  -U "$admin_username" \
  ${domain_fqdn} \
  --verbose

# ==============================================================================
# SSSD + PAM tweaks
# ------------------------------------------------------------------------------
# Match the DC's POSIX attributes (uidNumber/gidNumber) rather than algorithmic
# id mapping, drop the realm suffix from names, and flatten home paths.
# ==============================================================================
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' \
  /etc/sssd/sssd.conf
sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/' \
  /etc/sssd/sssd.conf
sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
  /etc/sssd/sssd.conf

# Create home dirs on first login (oddjobd) and allow AD password logins.
authselect select sssd with-mkhomedir --force
systemctl enable --now oddjobd

echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/60-passwordauth.conf
systemctl restart sshd

# ==============================================================================
# Samba member — re-export /s3 over SMB for Windows clients
# ==============================================================================
systemctl stop sssd

cat > /tmp/smb.conf <<EOF
[global]
workgroup = ${netbios}
security = ads

strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

kerberos method = secrets and keytab

template homedir = /home/%U
template shell = /bin/bash
#netbios

create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}

realm = ${realm}

idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999

winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60
winbind negative cache time = 0

[homes]
browseable = no
read only = no
inherit acls = yes

[s3]
path = /s3
read only = no
guest ok = no
EOF

cp /tmp/smb.conf /etc/samba/smb.conf
rm /tmp/smb.conf

# Derive the Samba NetBIOS name from the SHORT hostname. On AL2023 /etc/hostname
# is the FQDN (ip-10-0-0-110.mcloud.mikecloud.com), so slicing raw characters
# leaks the domain into the name. hostname -s drops everything past the first
# dot; then strip dashes, uppercase, and cap at the 15-char NetBIOS limit.
value=$(hostname -s | tr -d '-' | tr '[:lower:]' '[:upper:]')
netbios="$${value:0:15}"
sed -i "s/#netbios/netbios name=$netbios/" /etc/samba/smb.conf

cat > /tmp/nsswitch.conf <<EOF
passwd:     files sss winbind
group:      files sss winbind
automount:  files sss winbind
shadow:     files sss winbind
hosts:      files dns myhostname
services:   files sss
netgroup:   files sss
EOF

cp /tmp/nsswitch.conf /etc/nsswitch.conf
rm /tmp/nsswitch.conf

systemctl enable --now winbind smb nmb
systemctl restart winbind smb nmb sssd

# ==============================================================================
# Sudo + permissions
# ==============================================================================
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-linux-admins
sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis

chgrp mcloud-users /s3 /s3/data
chmod 770 /s3 /s3/data
chmod 700 /home/*

# Seed the share with a repo — files land as objects in the backing bucket,
# demonstrating that the S3 API and the NFS mount see the same data.
# Guard the clone: the bucket persists across instance replacements, so on a
# reboot/replace /s3/aws-s3-files already exists and a bare clone would abort.
cd /s3
if [ ! -d aws-s3-files/.git ]; then
  git clone https://github.com/mamonaco1973/aws-s3-files.git
fi
chmod -R 775 aws-s3-files
chgrp -R mcloud-users aws-s3-files
