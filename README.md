# Amazon S3 Files with Mini Active Directory: NFS and Samba File Sharing

A variant of the [AWS Mini Active Directory](https://github.com/mamonaco1973/aws-mini-ad)
file-sharing lab ([aws-efs](https://github.com/mamonaco1973/aws-efs)) that
uses **Amazon S3 Files** for storage. S3 Files presents an ordinary,
versioned S3 bucket as an **NFS 4.2** file system: the bucket stays the
source of truth, while S3 Files (built on Amazon EFS) serves the working set
and syncs writes back to S3.

A domain-joined Linux gateway mounts the file system for `/s3` and `/home`
and re-exports `/s3` over **Samba**, because S3 Files is NFS only; a
domain-joined Windows host maps that share as `Z:`. Users sign in to both
with their **mini-AD** accounts.

![The S3 Files mounts on the Linux gateway](linux.png)

| Piece | Where | Role |
|---|---|---|
| **mcloud-s3files** | S3 Files | file system over the bucket, using the `s3files-service-*` role; mount targets in `vm-subnet-1` and `ad-subnet` |
| **mcloud-s3files-&lt;suffix&gt;** | S3 | the backing bucket; versioned, public access blocked, `force_destroy` |
| **s3files-service-&lt;id&gt;** | IAM | assumed by `elasticfilesystem.amazonaws.com`; reads and writes the bucket and manages its EventBridge change rule |
| **s3-files-gateway** | `vm-subnet-1` (public), `t3.medium` | Amazon Linux 2023; joined to AD (SSSD plus winbind); mounts `fs:/` at `/s3` and `fs:/home` at `/home`; shares `/s3` over Samba as `[s3]` |
| **windows-ad-admin** | `vm-subnet-1` (public), `t3.medium` | Windows Server 2022; joined to AD; RSAT; maps `\\s3-files-gateway\s3` as `Z:` |
| **mini-AD** | `ad-subnet` (private) | [`module-aws-mini-ad`](https://github.com/mamonaco1973/module-aws-mini-ad) Samba DC for `mcloud.mikecloud.com` (`MCLOUD`) |
| **Instance role** | IAM | SSM, read on `admin_ad_credentials_s3`, and `s3files:ClientMount`, `ClientWrite` and `ClientRootAccess` on the file system |
| **Secrets Manager** | us-east-1 | `admin_ad_credentials_s3` and one `*_ad_credentials_s3` secret per user |
| **ad-vpc** | `10.0.0.0/24` | public `vm-subnet-1` (`use1-az6`), private `ad-subnet` (`use1-az4`), NAT gateway |

## Architecture

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="architecture-dark.svg">
  <img alt="An SSH client reaches s3-files-gateway, an Amazon Linux 2023 instance, and an RDP client reaches windows-ad-admin, a Windows Server 2022 instance; both are joined to a Samba mini-AD domain controller in a private subnet behind a NAT gateway and read the join password from Secrets Manager. The gateway mounts an Amazon S3 Files file system over NFS at /s3 and /home and shares /s3 over Samba; the Windows host maps that share as drive Z:. S3 Files serves the data from a versioned S3 bucket and syncs writes back to it." src="architecture-light.svg">
</picture>

Regenerate with `python3 make_diagram.py`. The gateway also reads the join
password from Secrets Manager; that line is left off the diagram.

- **`01-directory/`**: the VPC, subnets and NAT gateway, the AD passwords,
  and the mini-AD module with users and groups from
  `scripts/users.json.template`.
- **`02-servers/`**: the bucket, the S3 Files file system, its role and
  mount targets (`s3-files.tf`), the two instances and their user data, the
  instance role and the security groups.

## Understanding Amazon S3 Files

**Amazon S3 Files** gives file-based applications NFS access to data in a
standard S3 bucket, with no download-process-upload cycle and no second
copy of the data.

- You create a file system over a **versioned** bucket and put a **mount
  target** in each subnet that needs it.
- Clients mount it with the `mount.s3files` helper from
  **amazon-efs-utils 3.0 or later**: `mount -t s3files fs-xxxx:/ /mnt`.
- S3 Files caches the active working set on EFS-backed storage. Writes are
  aggregated (around 60 seconds) and synced back to S3.

**Good fits:** file applications that need data that lives in S3; ML and
analytics pipelines that read a bucket as files without copying it first;
many Linux compute resources (EC2, Lambda, ECS, EKS, Fargate, Batch)
sharing one dataset.

**Benefits:** data stays at S3 prices with no capacity planning or
provisioned throughput; high concurrency; the same objects are reachable
over NFS and the S3 API at once.

**Limits:**

- **NFS only.** No SMB, so Windows clients need a gateway like this one, or
  FSx.
- **Eventual sync.** File-system writes can take about a minute to show up
  through the S3 API.
- **Locks.** NFS locks don't apply to direct S3 API writes, so avoid two
  write paths to the same object.
- **Conflicts.** The bucket wins; conflicting file-system changes move to a
  `.s3files-lost+found-<file-system-id>` directory.
- **Versioning** must be on for the bucket.

For Windows-native SMB with ACLs and DFS, use **FSx for Windows File
Server**; for a plain shared NFS file system, **EFS**.

| Service | Cost per GB-month | 1 TB (approx.) | Notes |
|---|--:|--:|---|
| **S3 Standard** | $0.023 | $23.50 | the backing store for S3 Files |
| **S3 Files** | S3 storage plus usage | varies | file access is billed on top of S3 storage |
| **EBS gp3** | $0.080 | $81.92 | block storage for one instance |
| **EFS Standard** | $0.300 | $307.20 | shared NFS, elastic across AZs |

## How the gateway starts

`userdata.sh`, on the Linux gateway:

1. Installs realmd, SSSD, Samba and winbind, and `amazon-efs-utils` (which
   provides `mount.s3files`); sets SELinux to permissive.
2. Mounts the file system's root at `/s3`, creates `/s3/home` and
   `/s3/data`, and mounts `/s3/home` at `/home`. Both go in `/etc/fstab`.
3. Joins the domain with `realm join --membership-software=samba`; SSSD
   uses short names and the POSIX IDs from AD, with mkhomedir.
4. Writes `smb.conf` with `[homes]` and `[s3]` (files group-owned by
   `mcloud-users`), gives `linux-admins` sudo, and turns on SSH password
   sign-in.
5. Makes `/s3` and `/s3/data` `770` for `mcloud-users`, home directories
   `700`, and clones this repository into `/s3`.

The Windows host installs RSAT and the AWS CLI, joins the domain, lets
`mcloud-users` use RDP, maps `Z:` to the gateway's `s3` share and reboots.

## Users and groups

| User | uidNumber | Groups |
|---|---|---|
| jsmith | 10001 | mcloud-users, us, linux-admins, Domain Admins |
| edavis | 10002 | mcloud-users, us |
| rpatel | 10003 | mcloud-users, india, linux-admins, Domain Admins |
| akumar | 10004 | mcloud-users, india |

| Group | gidNumber |
|---|---|
| mcloud-users | 10001 (every user's primary group) |
| us | 10002 |
| india | 10003 |
| linux-admins | 10004 |

Linux reads these through SSSD using `uidNumber` and `gidNumber`, so they
must be set on every account.

## Prerequisites

* [An AWS Account](https://aws.amazon.com/console/)
* [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), **v2.34 or later** (S3 Files support)
* [Install Terraform](https://developer.hashicorp.com/terraform/install), with **AWS provider 6.40 or later** (the `aws_s3files_*` resources)

If this is your first time watching our content, we recommend starting with
this video: [AWS + Terraform: Easy Setup](https://youtu.be/BCMQo0CB9wk).

## Deploy

```bash
git clone https://github.com/mamonaco1973/aws-s3-files.git
cd aws-s3-files
./apply.sh
```

`apply.sh` runs `check_env.sh`, applies `01-directory` and then
`02-servers`, and ends by running `validate.sh`:

```
============================================================================
S3 Files + Active Directory Quick Start - Validation Output
============================================================================

NOTE: Windows RDP Host FQDN: ec2-x-x-x-x.compute-1.amazonaws.com
NOTE: Linux SSH Host FQDN:  ec2-x-x-x-x.compute-1.amazonaws.com

NOTE: Validation complete.
```

## Try it

1. SSH to the Linux host as one of the users above (password in its
   `*_ad_credentials_s3` secret), or connect with SSM, and look at the
   mounts with `df -h` and `ls -al /s3 /s3/home`, as in the screenshot
   above.
2. RDP to the Windows host as the same user and open `Z:`. The repository
   the gateway cloned is there:

   ![The S3-backed share as drive Z: on Windows](windows.png)

3. Create a file on either side, then find it as an object in the bucket
   with `aws s3 ls s3://mcloud-s3files-<suffix>/ --recursive` after about a
   minute.

## Teardown

```bash
./destroy.sh
```

`destroy.sh` destroys `02-servers`. If the file system won't delete (it
can wait on pending exports to S3), it force-deletes it with the AWS CLI,
removes it from state and destroys again. Then it deletes the five secrets
without a recovery window and destroys `01-directory`. The bucket has
`force_destroy`, so its objects go with it.

## Notes

- **Lab only.** RDP (3389), SSH (22) and SMB (445) are open to `0.0.0.0/0`
  on public IPs, and so is NFS on the S3 Files security group.
- The instance role has `s3files:ClientRootAccess`, so root on the gateway
  isn't squashed.
- `/home` is on S3 Files. With write aggregation and S3 API writes ignoring
  NFS locks, that's fine for a lab but a poor fit for busy interactive home
  directories.
- The old README listed `india` as 10002 and `us` as 10003; the template
  sets `us` to 10002 and `india` to 10003.
