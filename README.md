# k8s-setup

[![CI](https://github.com/greysquareus/k8s-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/greysquareus/k8s-setup/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazonaws&logoColor=white)

A one-command Kubernetes lab on AWS (**Terraform + kubeadm + Ansible**), with a built-in set of **CKA-style exercises** that are checked automatically.

```bash
make up        # provision 3 EC2 nodes, install Kubernetes and add-ons
make destroy   # tear everything down
```

## Contents

- [What you get](#what-you-get)
- [How it works](#how-it-works)
- [Quick start](#quick-start)
- [CKA lab](#cka-lab)
- [Adding your own exercise](#adding-your-own-exercise)
- [Configuration](#configuration)
- [Security notes](#security-notes)

## What you get

| Node      | Instance type | Role                          |
|-----------|---------------|-------------------------------|
| `master`  | t3.medium     | control plane (`kubeadm init`) |
| `worker1` | t3.small      | worker                        |
| `worker2` | t3.small      | worker                        |

- Ubuntu 22.04, containerd with `SystemdCgroup = true`, Kubernetes **v1.31**
- CNI: **Calico** v3.28 (pod CIDR `192.168.0.0/16`)
- Add-ons: **metrics-server**, **Gateway API** CRDs v1.6, **Envoy Gateway** (hostNetwork on ports 80/443), **cert-manager**, Helm
- `kubectl` completion and a `k` alias for the `ubuntu` user
- The admin kubeconfig is fetched to `ansible/kubeconfig`, so you can use `kubectl --kubeconfig ansible/kubeconfig` from your laptop right away

## How it works

```
┌──────────────┐  terraform apply   ┌────────────────────────────────────┐
│  Terraform   │ ─────────────────► │ VPC · subnet · IGW · SG · 3× EC2   │
│              │                    │ one SSH key pair per node          │
└──────┬───────┘                    └────────────────────────────────────┘
       │ renders ansible/inventory.ini
       ▼
┌──────────────┐  site.yml          ┌────────────────────────────────────┐
│   Ansible    │ ─────────────────► │ common → master → worker → addons  │
└──────────────┘                    └────────────────────────────────────┘
```

```
terraform/
  main.tf, locals.tf     nodes defined once in a map, created with for_each
  network.tf             VPC 10.0.0.0/16, public subnet, IGW, route table
  sec_group.tf           security group rules
  ssh.tf                 RSA 4096 key per node -> keys/<node>.pem
  inventory.tf           renders ansible/inventory.ini from templates/inventory.tftpl
ansible/
  site.yml               cluster bootstrap
  lab.yml                CKA exercise runner
  group_vars/all.yml     versions and URLs
  roles/
    common/              swap off, kernel modules, sysctl, containerd, kubeadm/kubelet/kubectl
    master/              kubeadm init, Calico, join command
    worker/              kubeadm join
    addons/              metrics-server, Gateway API, Envoy Gateway, cert-manager, shell niceties
    lab/                 exercise engine (deploy / hints / validate / solve / clean)
Makefile
```

Terraform writes the Ansible inventory itself, so nothing is copied by hand between `apply` and `ansible-playbook`. `make wait-ssh` blocks until sshd is up on every host, because EC2 reports a public IP well before cloud-init finishes.

## Quick start

**Requirements:** Terraform ≥ 1.5, Python 3, Ansible, and AWS credentials in the environment (`AWS_PROFILE` or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install ansible -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml

terraform -chdir=terraform init
make up

kubectl --kubeconfig ansible/kubeconfig get nodes
```

| Command          | What it does                                            |
|------------------|---------------------------------------------------------|
| `make plan`      | `terraform plan`                                        |
| `make apply`     | create the infrastructure                               |
| `make wait-ssh`  | wait until every node accepts SSH                       |
| `make configure` | `wait-ssh`, then run `ansible/site.yml`                 |
| `make up`        | `apply` + `configure`                                   |
| `make destroy`   | destroy the infrastructure and remove local kubeconfig / join command |

SSH into a node:

```bash
ssh -i keys/master.pem ubuntu@$(terraform -chdir=terraform output -raw ubuntu_ip_master)
```

## CKA lab

The `lab` role deploys deliberately broken manifests into the `cka` namespace, prints the task, and later validates your fix.

```bash
cd ansible
ansible-playbook lab.yml -e action=list                               # list exercises
ansible-playbook lab.yml -e task=task1-crashloop                      # deploy (default action)
ansible-playbook lab.yml -e task=task1-crashloop -e action=hints      # show hints
ansible-playbook lab.yml -e task=task1-crashloop -e action=validate   # check your fix
ansible-playbook lab.yml -e task=task1-crashloop -e action=solve      # apply the reference solution
ansible-playbook lab.yml -e task=task1-crashloop -e action=clean      # clean up
```

| Exercise             | Scenario                                   | CKA domain             | Difficulty | Time   |
|----------------------|--------------------------------------------|------------------------|------------|--------|
| `task1-crashloop`    | Pod stuck in `CrashLoopBackOff`            | Troubleshooting        | easy       | 5 min  |
| `task2-svc-selector` | Service has no Endpoints                   | Services & Networking  | easy       | 8 min  |
| `task3-scheduling`   | Pods `Pending` due to taint + nodeSelector | Workloads & Scheduling | medium     | 12 min |

Before deploying an exercise, the runner checks that the kubeconfig exists and the cluster answers. It also wipes the common resource kinds in the lab namespace, so every run starts from a clean state.

## Adding your own exercise

Create a directory `ansible/roles/lab/tasks_lib/<name>/`:

| File                | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `meta.yml`          | `title`, `domain`, `difficulty`, `time`, `hints`, `debrief`    |
| `brief.md.j2`       | task statement shown to the student                            |
| `broken.yaml.j2`    | the broken manifests                                           |
| `solution.yaml.j2`  | reference solution                                             |
| `validate.yml`      | checks (`kubernetes.core.k8s_info` + `assert`)                 |
| `setup.yml`         | *(optional)* node preparation such as taints or labels         |
| `cleanup.yml`       | *(optional)* undo what `setup.yml` did                         |

The new exercise shows up in `action=list` straight away.

## Configuration

| Where                               | What                                                            |
|-------------------------------------|-----------------------------------------------------------------|
| `terraform/locals.tf`               | node names, instance types, roles                               |
| `terraform/main.tf`                 | AWS region (`us-east-1`)                                        |
| `ansible/group_vars/all.yml`        | Kubernetes series, pod CIDR, Calico / Gateway API / Helm / Envoy / cert-manager versions |
| `ansible/roles/lab/defaults/main.yml` | lab namespace, kubeconfig path, kinds wiped between runs     |

## Security notes

This is a **lab**, not a production cluster:

- SSH (22), the API server (6443), HTTP/HTTPS (80/443) and the NodePort range (30000–32767) are open to `0.0.0.0/0`
- Host key checking is disabled for Ansible
- metrics-server runs with `--kubelet-insecure-tls`
- `ansible/kubeconfig` holds cluster-admin credentials. Never commit it.

Run `make destroy` when you are done: three instances cost money every hour they run.
