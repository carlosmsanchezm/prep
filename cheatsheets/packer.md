# Packer Cheatsheet — Memorize This

> **Anduril is just starting to explore Packer** (Taylor brought it up). Know the basics — you might be the one implementing it.

## What Packer Does

Packer builds **identical machine images** from a single template. Define it once → build for any platform (AWS AMI, Docker/Podman image, VMware, bare-metal ISO). Replaces manual "install and configure" with automated, reproducible image creation.

## Template Structure (HCL2 — modern format)

```hcl
# rhel-base.pkr.hcl

packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Source: what to build FROM
source "docker" "rhel" {
  image  = "registry.local/rhel9:latest"
  commit = true
}

# Build: what to DO to it
build {
  sources = ["source.docker.rhel"]

  # Provision with shell
  provisioner "shell" {
    inline = [
      "dnf update -y",
      "dnf install -y ansible-core python3"
    ]
  }

  # Provision with Ansible
  provisioner "ansible" {
    playbook_file = "./ansible/harden.yml"
    extra_arguments = [
      "--extra-vars", "env=production"
    ]
  }

  # Post-process: tag the image
  post-processor "docker-tag" {
    repository = "registry.local/rhel9-hardened"
    tags       = ["latest", "v1.0"]
  }
}
```

## Common Sources (builders)

| Source | What It Builds | Use At Anduril |
|--------|---------------|----------------|
| `docker` | Container image | YES — Podman-compatible (set DOCKER_HOST to podman.sock) |
| `amazon-ebs` | AWS AMI | Only for unclass/cloud side |
| `qemu` | VM image (KVM) | Possible for bare-metal provisioning |
| `vsphere-iso` | VMware image | If they use VMware |
| `file` | Local file output | For testing |

## Provisioners (how to configure the image)

```hcl
# Shell (simple commands)
provisioner "shell" {
  inline = [
    "dnf install -y nginx podman",
    "systemctl enable nginx"
  ]
}

# Shell script from file
provisioner "shell" {
  script = "./scripts/setup.sh"
}

# Ansible playbook (the big one)
provisioner "ansible" {
  playbook_file   = "./ansible/site.yml"
  extra_arguments = ["--extra-vars", "target=production"]
}

# Ansible local (runs inside the image, no SSH needed)
provisioner "ansible-local" {
  playbook_file = "./ansible/site.yml"
}

# File upload
provisioner "file" {
  source      = "./configs/nginx.conf"
  destination = "/etc/nginx/nginx.conf"
}
```

## Using Packer with Podman (Anduril-relevant)

```bash
# Set Podman socket as Docker host
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock

# Packer's docker builder talks to Podman through this socket
# No code changes needed — it's API-compatible

# Build
packer init .                    # download plugins
packer validate .                # check syntax
packer build rhel-base.pkr.hcl   # build the image

# The built image lands in Podman's local store
podman images                    # see it here
```

## The Anduril Use Case

Felipe described their current pain:
1. Write an Ansible playbook
2. Manually SSH to a machine
3. Run the playbook
4. Check if it worked
5. If not, debug, fix, repeat

**Packer fixes this:**
1. Write a Packer template that uses Ansible as provisioner
2. GitLab CI triggers `packer build` on push
3. Packer spins up a container (via Podman), runs the playbook INSIDE it
4. If playbook fails → build fails → pipeline fails → visible in MR
5. If it passes → tagged image pushed to Nexus → ready for deployment

```
GitLab MR → Pipeline → Packer build → Ansible runs inside container → Pass? → Push to Nexus
                                                                    → Fail? → Pipeline red, fix and retry
```

## Key Commands

```bash
packer init .              # download required plugins
packer validate .          # syntax check (like ansible --syntax-check)
packer fmt .               # auto-format HCL files
packer build .             # build the image
packer build -var 'version=1.2' .  # pass variables
packer build -only='docker.rhel' . # build only one source
```

## Variables

```hcl
# In the template
variable "base_image" {
  type    = string
  default = "registry.local/rhel9:latest"
}

source "docker" "rhel" {
  image = var.base_image
}

# Override at build time
# packer build -var 'base_image=registry.local/rhel8:latest' .
```

## Key Things to Know for Anduril Interview

1. **Packer + Ansible = golden images** — build hardened base images automatically
2. **Works with Podman** — just set DOCKER_HOST to podman socket
3. **GitLab CI integration** — trigger builds in pipeline, fail on errors
4. **Idempotent** — same template = same image every time
5. **Solves their testing problem** — instead of SSH + manual run, pipeline validates automatically
6. **Felipe explicitly said** Taylor is exploring Packer — you could own this
