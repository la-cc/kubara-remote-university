# Cluster API STACKIT

This umbrella chart installs the official Cluster API Operator and asks it to
manage these providers:

- Cluster API core `v1.13.2`
- kubeadm bootstrap provider `v1.13.2`
- kubeadm control-plane provider `v1.13.2`
- STACKIT infrastructure provider (CAPSTK) `v0.1.0-alpha.2`

Kamaji is intentionally not part of this chart. Workload clusters use
`KubeadmControlPlane` and STACKIT virtual machines for both control-plane and
worker nodes.

The operator Helm hooks are disabled because Argo CD applies the emitted sync
waves. Provider namespaces are created before their provider resources.

See `examples/cluster-api-stackit` for a complete, explicitly applied workload
cluster example. Installing this chart alone does not create billable STACKIT
infrastructure.
