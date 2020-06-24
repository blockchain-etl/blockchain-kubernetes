# tezos

[Tezos](https://tezos.com) is a distributed consensus platform with meta-consensus capability. Tezos not only comes to consensus about the state of its ledger, like Bitcoin or Ethereum.
It also attempts to come to consensus about how the protocol and the nodes should adapt and upgrade.
## Introduction

This chart bootstraps a single tezos node deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.
Docker image was taken from [tezos on Docker hub](https://hub.docker.com/r/tezos/tezos/tags)

## Prerequisites

- Kubernetes 1.8+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
$ helm install --name my-release stable/tezos
```

The command deploys tezos on the Kubernetes cluster in the default configuration.
The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the tezos chart and their default values.

Parameter                 	 	| Description                        				| Default
------------------------------- | ------------------------------------------------- | ----------------------------------------------------------
`image.repository`         		| Image source repository name       				| `arilot/docker-tezos`
`image.tag`                		| `tezos` release tag.            				| `0.17.1`
`image.pullPolicy`         		| Image pull policy                  				| `IfNotPresent`
`service.rpcPort`          		| RPC port                           				| `8732`
`service.p2pPort`          		| P2P port                           				| `9732`
`persistence.enabled`      		| Create a volume to store data      				| `true`
`persistence.accessMode`   		| ReadWriteOnce or ReadOnly          				| `ReadWriteOnce`
`persistence.size`         		| Size of persistent volume claim    				| `300Gi`
`resources`                		| CPU/Memory resource requests/limits				| `{}`
`terminationGracePeriodSeconds` | Wait time before forcefully terminating container | `30`


Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install --name my-release -f values.yaml stable/tezos
```

> **Tip**: You can use the default [values.yaml](values.yaml)

