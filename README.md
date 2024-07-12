# Introduction

This directory contains a set of shell scripts for quickly getting a server up with Azure Arc, K3s, Azure IoT Operations (AIO) and Edge Storage Accelerator (ESA). Files are broken down by component to allow substitution (e.g. K8s instead of K3s) or installation at different times.

## Prerequisites

These scripts were built and tested on Ubuntu 22.04. The only other tool required for all install scripts, with the exception of k3s_setup.sh, is the Azure CLI:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

All scripts assume that you are logged into the appropriate Azure tenant via the Azure CLI, scoped to the appropriate subscription.

```bash
az login -t <tenantId>
az account set -s <subscriptionId>
```

NOTE: If you are using SSH to interact with the server that is being configured, you may not have access to a browser for the az login. In that case use the following command to use the device code login sequence:

```bash
az login -t <tenantId> --use-device-code
```

## Execution

Starting from a base install of Ubuntu 22.04 with the AZ CLI, the following steps should be followed. Note that all shell scripts are designed to be run without modification, based on variables defined in config.env, but are intended to be modified based on situational requirements.

Each script, with the exception of K3s which needs no variables, are run by passing in the config.env file:

```bash
./arc_server_setup.sh ./config.env
```

The scripts should be run in the following order:

1. Edit [config.env](./src/config.env) to set the appropriate values for your environment.
1. [Arc Server setup](./src/arc_server_setup.sh) (**NOTE**: this is not strictly necessary for the rest of the components)
1. [K3s setup](./src/k3s_setup.sh)
1. [Arc Kubernetes setup](./src/arc_setup.sh)
1. [AIO setup](./src/aio_setup.sh)
1. [ESA setup](./src/esa_server_setup.sh)  
1. [ESA Bottomless Ingest setup](./src/esa_bottomless_ingest.sh)
