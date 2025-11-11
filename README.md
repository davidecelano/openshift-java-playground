# OpenShift Java Container Playground

Reproducible experiments for testing Java applications on OpenShift across multiple OpenJDK versions, container runtimes, and resource configurations.

## Repository Structure

```
openshift-java-playground/
├── .github/
│   ├── copilot-instructions.md         # AI agent guidance
│   └── workflows/
│       └── build-metrics-samples.yml   # CI/CD for multi-version builds
├── metrics-sample-undertow/            # Lightweight Undertow server
├── metrics-sample-springboot/          # Spring Boot with embedded Tomcat
├── metrics-sample-tomcat/              # Standalone Apache Tomcat
└── metrics-sample-wildfly/             # WildFly / JBoss EAP style
```

## Sample Applications

Each sample exposes Prometheus JVM metrics and is built across **OpenJDK 11, 17, 21, and 23** on Red Hat UBI base images:

| Runtime | Description | Memory Limit | Max Threads | Metrics Path |
|---------|-------------|--------------|-------------|--------------|
| **Undertow** | Minimal non-blocking server | 512Mi | IO × 8 workers | `/metrics` |
| **Spring Boot** | Actuator + embedded Tomcat | 768Mi | 50 (configurable) | `/actuator/prometheus` |
| **Tomcat** | Standalone servlet container | 768Mi | 100 (configurable) | `/metrics` |
| **WildFly** | Full Jakarta EE app server | 1Gi | 80 (configurable) | `/metrics` (port 9990) |

## Quick Start

### Prerequisites
- OpenShift 4.x cluster access (`oc` CLI configured)
- Git repository clone
- (Optional) Podman/Docker for local builds

### OpenShift-Native Build (Recommended)

```bash
# Trigger builds from Git source
cd scripts
./trigger-openshift-builds.sh

# Deploy to cluster
./deploy-all.sh
```

### Local Development Build

```bash
# Build locally and push to registry
REGISTRY=quay.io/yourorg ./scripts/build-all.sh
REGISTRY=quay.io/yourorg ./scripts/push-all.sh
./scripts/deploy-all.sh
```

## Image Version Management

All container images use pinned versions for reproducibility. See [`VERSIONS.md`](VERSIONS.md) for:
- Current UBI OpenJDK image tags
- WildFly image versions
- Update procedures and lifecycle information

**Never use `:latest` tags in production scenarios.**

### Dynamic Version Overrides

Override image versions per-build without modifying files:

```bash
# Override OpenJDK builder image
BUILDER_IMAGE_17=registry.../openjdk-17:1.22 ./scripts/build-all.sh

# Override Tomcat version
TOMCAT_VERSION=10.1.16 ./scripts/build-all.sh

# Override multiple versions
BUILDER_IMAGE_17=registry.../openjdk-17:1.22 \
RUNTIME_IMAGE_17=registry.../openjdk-17-runtime:1.22 \
WILDFLY_IMAGE_17=quay.io/wildfly/wildfly:31.0.2.Final-jdk17 \
./scripts/build-all.sh
```

All Dockerfiles use `ARG` directives with defaults from `VERSIONS.md`, enabling flexible version management for experiments and testing.

### Access Metrics
```bash
# Port-forward to a pod
oc port-forward deployment/metrics-undertow-openjdk17 8080:8080

# Check health
curl http://localhost:8080/health

# Scrape metrics
curl http://localhost:8080/metrics | grep jvm_memory
```

## Container Tuning Essentials

All samples follow these tuning patterns documented in `.github/copilot-instructions.md`:

### Memory
- **MaxRAMPercentage**: 65-70% for balanced workloads
- **InitialRAMPercentage**: 50% for stable startup
- **Headroom**: Reserve 25-35% for metaspace, JIT, native buffers, GC overhead

### CPU & Threads
- Thread pools sized to **container CPUs**, not host cores
- Override detection: `-XX:ActiveProcessorCount=<n>`
- Undertow: IO threads ≈ vCPUs, workers = IO × 8
- Tomcat/Spring Boot: max threads ≈ 4× vCPUs for mixed I/O workloads
- WildFly: JBOSS_MAX_THREADS ≈ 2-4× vCPUs

### Container Awareness
- Enabled by default in OpenJDK 8u191+, 10+
- Validate with: `-Xlog:os+container=info`
- Cgroups v2 support: OpenJDK 8u372+, 11+

## Metrics Exposed

All samples expose standard JVM metrics:

```
jvm_memory_used_bytes{area="heap"}
jvm_memory_max_bytes{area="heap"}
jvm_gc_pause_seconds_count
jvm_gc_pause_seconds_sum
jvm_threads_live_threads
jvm_classes_loaded_classes
process_cpu_usage
system_cpu_usage
```

## GitHub Actions CI/CD

Manual multi-version builds via `.github/workflows/build-metrics-samples.yml`:

- **Manual trigger only** (workflow_dispatch)
- Matrix build across OpenJDK 11, 17, 21, 23
- Pushes images to Quay.io (requires `QUAY_USERNAME` and `QUAY_PASSWORD` secrets)
- Use for local registry workflows when OpenShift builds unavailable

**Primary build method**: OpenShift BuildConfig from Git source

## Experiment Ideas

Use these samples to compare:

1. **Heap ergonomics**: Default sizing across Java versions under identical limits
2. **GC behavior**: Pause times, throughput, memory pressure
3. **Startup time**: Cold start performance vs initial heap settings
4. **Thread scaling**: Request throughput vs thread pool size
5. **Native memory**: RSS growth, metaspace usage, JIT overhead
6. **Cgroups v1 vs v2**: Parsing accuracy, limit enforcement

## Contributing

See `.github/copilot-instructions.md` for repository conventions and tuning patterns. 

New scenarios should:
- Use descriptive directory names (e.g., `tuning-cgroups-v2/`)
- Include a `README.md` with goals, setup steps, and expected results
- Provide reproducible scripts and baseline captures
- Document Java version, container runtime, and resource limits

## References

- [OpenJDK Container Awareness](https://developers.redhat.com/articles/2024/03/14/how-use-java-container-awareness-openshift-4)
- [Scaling Java Containers](https://blog.openshift.com/scaling-java-containers/)
- [Memory Tuning Overhaul](https://developers.redhat.com/articles/2023/03/07/overhauling-memory-tuning-openjdk-containers-updates)
- [Cgroups v2 Support](https://developers.redhat.com/articles/2023/04/19/openjdk-8u372-feature-cgroup-v2-support)

---

**Focus**: OpenJDK only (community / Red Hat builds). Oracle commercial features excluded.
