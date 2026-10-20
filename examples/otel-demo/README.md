## Example 5: add Tempo + OTel for more insights

**Note:** We are not experts at OTel and observability, so you should not take this example as education on OTel itself. It shows how you can
integrate it into your workflow to get more insights and provide self-service auto-instrumentation for your developers.

You can find my extended catalog in the example 5 folder, which shows how I add the components to work with kubara.
You don't need it, you can easily integrate the components into your own workflow.

The key points are to add and deploy:

- `opentelemetry-collector` - umbrella Helm chart
- `opentelemetry-operator` - umbrella Helm chart
- `tempo` - umbrella Helm chart
- Grafana configuration, so you can use Tempo as a data source - config change
- Example application `otel-demo`, auto-instrumented so you can see the traces - new Deployment

```text
app (auto-instrumented by the Operator)
  -> OTLP -> OpenTelemetry Collector
                |-> traces  -> Tempo -> Grafana (Explore)
                '-> metrics -> Prometheus (remote write)
```

### 1. Umbrella charts and service definitions

Each component is an umbrella chart in `my-catalog/platform-components/helm/<name>/` with a matching
`ServiceDefinition` in `my-catalog/services/<name>.yaml`.

```yaml
# my-catalog/platform-components/helm/tempo/Chart.yaml
apiVersion: v2
name: tempo
type: application
version: 1.0.0
dependencies:
  - name: tempo
    repository: https://grafana.github.io/helm-charts
    version: 1.24.4
```

```yaml
# my-catalog/services/tempo.yaml
apiVersion: kubara.io/v1alpha1
kind: ServiceDefinition
metadata:
  name: tempo
  annotations:
    kubara.io/category: observability
spec:
  chartPath: tempo
  status: enabled
  clusterTypes:
    - hub
```

The same pattern is used for the other two charts:

| Chart | Upstream repository | Version |
|---|---|---|
| `opentelemetry-collector` | `https://open-telemetry.github.io/opentelemetry-helm-charts` | 0.176.0 |
| `opentelemetry-operator` | `https://open-telemetry.github.io/opentelemetry-helm-charts` | 0.126.1 |
| `tempo` | `https://grafana.github.io/helm-charts` | 1.24.4 |

The Operator uses cert-manager for its admission webhook, which kubara already deploys.

Enable the services in `config.yaml`, then build the dependencies and generate:

```yaml
# config.yaml (excerpt)
services:
  opentelemetry-collector:
    status: enabled
  opentelemetry-operator:
    status: enabled
  tempo:
    status: enabled
```

```bash
helm dependency build my-catalog/platform-components/helm/<chart>
kubara generate --helm --catalog ./my-catalog
```

### 2. Collector: receive OTLP, export to Tempo and Prometheus

```yaml
# my-catalog/platform-components/helm/opentelemetry-collector/values.yaml (excerpt)
opentelemetry-collector:
  config:
    exporters:
      otlp/tempo:
        endpoint: tempo.tempo.svc.cluster.local:4317
        tls:
          insecure: true
      prometheusremotewrite:
        endpoint: http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc:9090/prometheus/api/v1/write
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, resource/platform, batch]
          exporters: [otlp/tempo]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, resource/platform, batch]
          exporters: [prometheusremotewrite]
```

The `/prometheus` path comes from the `routePrefix` of the Prometheus in this setup. Adjust it to yours.

### 3. Grafana: add Tempo as data source and enable remote write

Prometheus must accept remote write, and Grafana needs the Tempo data source. A `values-*.yaml` file in the platform config
directory is picked up by Argo CD and is not overwritten by `kubara generate`.

```yaml
# platform-configs/hub/helm/kube-prometheus-stack/values-otel.yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      enableRemoteWriteReceiver: true
  grafana:
    # Lists are replaced by Helm, so loki from values.generated.yaml is repeated here
    additionalDataSources:
      - access: proxy
        isDefault: false
        name: loki
        type: loki
        url: http://loki-headless.loki.svc.cluster.local:3100
        version: 1
      - access: proxy
        isDefault: false
        name: Tempo
        uid: tempo
        type: tempo
        url: http://tempo.tempo.svc.cluster.local:3200
        version: 1
        jsonData:
          nodeGraph:
            enabled: true
```

Helm replaces lists instead of merging them, so the existing Loki data source is repeated here.

If your ServiceMonitors are selected by a label (here `monitoring.instance: hub-dev`), set it on the new
components too, for example `serviceMonitor.additionalLabels` for Tempo.

### 4. Demo app: auto-instrumentation

The app is in [otel-demo.yaml](./otel-demo.yaml): a small Node.js HTTP server, a load generator and an `Instrumentation` resource.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: default
  namespace: otel-demo
spec:
  exporter:
    endpoint: http://opentelemetry-collector.opentelemetry-collector.svc:4318
  env:
    - name: OTEL_EXPORTER_OTLP_PROTOCOL
      value: http/protobuf
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
```

Developers only add one annotation to their Deployment. The Operator injects the SDK at pod start, no code change needed:

```yaml
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "otel-demo/default"
```

Other languages use `inject-java`, `inject-python`, `inject-dotnet` and `inject-go`.

```bash
kubectl apply -f examples/otel-demo/otel-demo.yaml
```

### 5. Verify

```bash
# The Operator added the init container
kubectl -n otel-demo get pod -l app=hello -o jsonpath='{.items[0].spec.initContainers[*].name}'
# opentelemetry-auto-instrumentation-nodejs

# The Collector receives and exports without errors
kubectl -n opentelemetry-collector logs deploy/opentelemetry-collector --tail=50
```

In Grafana, open **Explore**, select **Tempo** and run:

```text
{ resource.service.name = "hello" }
```

### Notes

- Service names and namespaces in the endpoints depend on your Helm release and namespace names. Check them with `kubectl get svc -A`.
- The sampler `1.0` keeps every trace. Lower it for busy services.
