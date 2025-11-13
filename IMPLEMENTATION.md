# Technical Implementation Guide

📚 **Documentation**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Deployment](DEPLOYMENT.md) | [Testing](TESTING.md) | [Versions](VERSIONS.md) | [Version Management](VERSION_MANAGEMENT.md) | [Contributing](CONTRIBUTING.md)

---

This guide explains the technical architecture, design decisions, and implementation details of the OpenShift Java container playground. For getting started, see [Quick Start](QUICKSTART.md). For deployment procedures, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Container Image Build System](#container-image-build-system)
- [Runtime-Specific Implementations](#runtime-specific-implementations)
- [Metrics Integration Architecture](#metrics-integration-architecture)
- [Container Awareness Mechanisms](#container-awareness-mechanisms)
- [Security Design Patterns](#security-design-patterns)
- [Design Decisions & Rationale](#design-decisions--rationale)

---

## Architecture Overview

### Repository Purpose
This repository serves as a **reproducible experiment platform** for studying Java application behavior in containerized OpenShift environments. It focuses exclusively on **OpenJDK** (community and Red Hat builds) across multiple versions and runtime servers.

### High-Level Flow

```
┌─────────────────┐
│  Git Repository │
│  (Source Code)  │
└────────┬────────┘
         │
         ├──────────────────────────┬─────────────────────────┐
         ▼                          ▼                         ▼
┌────────────────┐       ┌────────────────────┐   ┌─────────────────┐
│ Local Build    │       │ OpenShift          │   │ GitHub Actions  │
│ (Podman/Maven) │       │ BuildConfig        │   │ (CI/CD)         │
└────────┬───────┘       └─────────┬──────────┘   └────────┬────────┘
         │                         │                        │
         ▼                         ▼                        ▼
┌──────────────────────────────────────────────────────────────┐
│              Container Registry (Quay.io / Internal)         │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  OpenShift Cluster   │
                  │  (Deployment)        │
                  └──────────┬───────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
            ┌──────────────┐  ┌─────────────────┐
            │ Application  │  │ Prometheus      │
            │ Pods         │  │ (Metrics)       │
            └──────────────┘  └─────────────────┘
```

### Multi-Version Strategy
Each sample runtime supports **4 Java versions** (11, 17, 21, 23) with:
- Separate Dockerfiles per version (`Dockerfile.openjdk{11,17,21,23}`)
- Separate deployment manifests per version (`deployment-openjdk{11,17,21,23}.yaml`)
- Separate OpenShift BuildConfigs per version (`buildconfig-openjdk{11,17,21,23}.yaml`)

This enables direct comparison of:
- **Container awareness evolution** (Java 8 → 11 → 17 → 21 → 23)
- **JVM ergonomics improvements** (heap sizing, GC algorithm selection)
- **Startup performance** across versions
- **Runtime memory footprint** differences

---

## Container Image Build System

### Dockerfile Architecture

#### Multi-Stage Build Pattern
All Dockerfiles use a **two-stage build**:

1. **Builder Stage**: Compiles Java application using Maven
   - Uses UBI OpenJDK image with full JDK + Maven
   - Produces JAR/WAR artifact
   - Discarded after build (reduces final image size)

2. **Runtime Stage**: Creates minimal runtime image
   - Uses UBI OpenJDK runtime image (JRE only)
   - Copies artifact from builder stage
   - Non-root user (`jboss`, UID 185)
   - Minimal attack surface

**Example Structure** (Undertow):
```dockerfile
# Builder stage
FROM registry.access.redhat.com/ubi9/openjdk-17:1.21 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.21
COPY --from=builder /build/target/*.jar /app/app.jar
USER 185
EXPOSE 8080
CMD ["java", "-Xlog:os+container=info", "-XX:MaxRAMPercentage=65.0", "-jar", "/app/app.jar"]
```

### Dynamic Version Management via ARG

All Dockerfiles use **ARG directives** for version flexibility without file modification:

```dockerfile
ARG BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.21
ARG RUNTIME_IMAGE=registry.access.redhat.com/ubi9/openjdk-17-runtime:1.21

FROM ${BUILDER_IMAGE} AS builder
...
FROM ${RUNTIME_IMAGE}
```

**Build-Time Override**:
```bash
podman build -f Dockerfile.openjdk17 \
  --build-arg BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.20 \
  -t myapp:latest .
```

**OpenShift BuildConfig** (see [DEPLOYMENT.md](DEPLOYMENT.md#openshift-buildconfig-cluster-native-builds)):
```yaml
strategy:
  dockerStrategy:
    buildArgs:
      - name: BUILDER_IMAGE
        value: "registry.access.redhat.com/ubi9/openjdk-17:1.20"
```

### Build Scripts Architecture

**`scripts/build-all.sh`**:
- Iterates through all 4 sample directories
- Builds all Dockerfiles per sample (4 per sample = 16 total)
- Supports registry override via `REGISTRY` environment variable
- Supports version overrides via environment variables (see [VERSIONS.md](VERSIONS.md))
- Parallel builds possible via background jobs

**Environment Variable Pattern**:
```bash
export BUILDER_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17:1.20
export RUNTIME_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17-runtime:1.20
./scripts/build-all.sh
```

### OpenShift BuildConfig Architecture

**ImageStream Pattern**:
- Each sample has one ImageStream with multiple tags (`:openjdk11`, `:openjdk17`, etc.)
- `lookupPolicy.local: false` enables cross-project references
- Acts as internal registry pointer

**BuildConfig Strategy**:
- `dockerStrategy` with explicit Dockerfile path (`dockerfilePath: Dockerfile.openjdk17`)
- Git source with `contextDir` pointing to sample directory
- `forcePull: true` ensures fresh base image pulls
- `buildArgs` support for version overrides
- Output to ImageStreamTag (e.g., `metrics-undertow:openjdk17`)

**Trigger Architecture**:
- `ConfigChange` trigger: rebuild on BuildConfig changes
- `ImageChange` trigger: rebuild on base image updates
- Manual trigger via `oc start-build` or `scripts/trigger-openshift-builds.sh`

See [DEPLOYMENT.md](DEPLOYMENT.md#openshift-buildconfig-cluster-native-builds) for complete BuildConfig documentation.

---

## Runtime-Specific Implementations

### 1. Undertow (Lightweight Embedded Server)

**Why Undertow?**
- Minimal footprint (512Mi memory limit)
- Low-latency HTTP server
- Direct NIO control (IO threads configurable)
- Baseline for comparing heavier frameworks

**Architecture**:
```
Main.java
  └─> Undertow.builder()
       ├─> setIoThreads(min(2, availableProcessors()))
       ├─> setWorkerThreads(ioThreads * 8)
       ├─> addHttpListener(8080)
       └─> setHandler(RoutingHandler)
            ├─> /health → HealthHandler
            └─> /metrics → MetricsHandler
                           └─> PrometheusMeterRegistry
```

**Key Configuration**:
- **IO Threads**: Minimum of 2 or available vCPUs (container-aware via `Runtime.getRuntime().availableProcessors()`)
- **Worker Threads**: IO threads × 8 (XNIO default)
- **Heap Sizing**: `MaxRAMPercentage=65.0` (leaves ~35% for native/GC/JIT)

**Metrics Integration**:
- Micrometer with Prometheus registry
- Custom `MetricsHandler` serializes registry to Prometheus format
- JVM metrics auto-registered (memory, GC, threads, classes)

**Thread Pool Rationale**:
- IO threads handle connection acceptance and non-blocking I/O
- Worker threads handle blocking operations
- Formula (IO × 8) balances I/O-bound vs CPU-bound workloads

### 2. Spring Boot (Embedded Tomcat)

**Why Spring Boot?**
- Most popular Java framework (industry standard)
- Built-in Actuator for metrics
- Larger footprint tests container headroom
- Demonstrates framework overhead impact

**Architecture**:
```
Application.java (@SpringBootApplication)
  └─> Spring Boot auto-configuration
       ├─> Embedded Tomcat (spring-boot-starter-web)
       ├─> Micrometer + Prometheus registry (spring-boot-starter-actuator)
       ├─> /actuator/health → Health endpoint
       └─> /actuator/prometheus → Prometheus metrics endpoint
```

**Key Configuration**:
- **Max Threads**: Configurable via `server.tomcat.max-threads` or `TOMCAT_MAX_THREADS` env var (default 50)
- **Heap Sizing**: `MaxRAMPercentage=70.0` (larger than Undertow but still leaves headroom)
- **Memory Limit**: 768Mi (accommodates Spring framework + dependency graph)

**Metrics Integration**:
- Spring Boot Actuator dependency (`spring-boot-starter-actuator`)
- Micrometer Prometheus registry dependency (`micrometer-registry-prometheus`)
- Auto-configuration registers JVM metrics
- Endpoint: `/actuator/prometheus`

**Startup Optimization**:
- `InitialRAMPercentage=50.0` pre-sizes heap, reducing early GC during bean initialization
- Larger initial heap critical for Spring's dependency injection overhead

### 3. Tomcat (Standalone Servlet Container)

**Why Standalone Tomcat?**
- Classic enterprise servlet container
- Control over Tomcat version (not embedded)
- Demonstrates manual Tomcat installation in containers
- Baseline for comparing embedded vs standalone overhead

**Architecture**:
```
Dockerfile
  └─> Downloads Apache Tomcat binary
       ├─> Extracts to /opt/tomcat
       ├─> Removes default webapps
       ├─> Copies metrics.war as ROOT.war
       └─> CMD catalina.sh run
            └─> Deploys WAR
                 ├─> HealthServlet (/health)
                 └─> MetricsServlet (/metrics)
                      └─> PrometheusMeterRegistry
```

**Key Configuration**:
- **Max Threads**: Configurable via `server.xml` Connector `maxThreads` or `TOMCAT_MAX_THREADS` env var (default 100)
- **Heap Sizing**: `MaxRAMPercentage=70.0`
- **Memory Limit**: 768Mi
- **JVM Flags**: Passed via `CATALINA_OPTS` environment variable

**Metrics Integration**:
- Servlet-based metrics exposure (`MetricsServlet`)
- Micrometer Prometheus registry in servlet context
- JVM metrics registered on servlet initialization
- Endpoint: `/metrics`

**UBI 9 Specifics**:
- Uses `microdnf` (not `yum`) for package installation
- Requires `tar` and `gzip` packages for Tomcat extraction
- Downloads Tomcat from Apache mirrors

**Thread Pool Sizing**:
- Default 100 threads higher than Spring Boot (50) to handle servlet concurrency
- Formula: ~4× vCPUs for I/O-heavy workloads

### 4. WildFly (Full Jakarta EE Application Server)

**Why WildFly?**
- Full Jakarta EE profile
- Subsystem architecture (modules)
- Built-in Micrometer subsystem (WildFly 34+)
- Management interface separation (port 9990)
- Demonstrates enterprise server overhead

**Architecture**:
```
Dockerfile
  └─> FROM quay.io/wildfly/wildfly:{version}
       ├─> Copies metrics.war to /opt/jboss/wildfly/standalone/deployments/
       ├─> Standalone server boots
       │    ├─> HTTP on port 8080 (application traffic)
       │    └─> Management on port 9990 (metrics/admin)
       └─> Micrometer subsystem auto-registers metrics
            └─> Endpoint: http://localhost:9990/metrics
```

**Key Configuration**:
- **Max Threads**: Configurable via `JBOSS_MAX_THREADS` env var (default 80)
- **Heap Sizing**: `MaxRAMPercentage=65.0` (lower than Tomcat due to larger native footprint)
- **Memory Limit**: 1Gi (largest of all runtimes due to module overhead)
- **Metrics Port**: 9990 (management interface, separate from application port 8080)

**Metrics Integration**:
- **WildFly 34+ / 38+**: Built-in Micrometer subsystem (no manual configuration)
- Metrics auto-registered via `micrometer-registry-prometheus` module
- Endpoint: `/metrics` on management port (9990)
- Namespace: `base_` prefix (Microprofile base metrics)

**Version Selection**:
- **Java 11**: WildFly 34.0.1.Final (last version supporting Java 11)
- **Java 17/21/23**: WildFly 38.0.0.Final (latest stable)

**Legacy Note**:
- WildFly < 34 required manual Micrometer CLI configuration (removed in migration)

---

## Metrics Integration Architecture

### Micrometer Core Pattern
All runtimes use **Micrometer** as the metrics facade:

```
Application Metrics
       │
       ▼
┌──────────────────┐
│ Micrometer Core  │  (io.micrometer:micrometer-core)
└────────┬─────────┘
         │
         ▼
┌───────────────────────┐
│ Prometheus Registry   │  (io.micrometer:micrometer-registry-prometheus)
└────────┬──────────────┘
         │
         ▼
┌───────────────────────┐
│ Prometheus Endpoint   │  (/metrics or /actuator/prometheus)
└───────────────────────┘
         │
         ▼
┌───────────────────────┐
│ Prometheus Scraper    │  (via ServiceMonitor)
└───────────────────────┘
```

### Metric Categories

**1. JVM Metrics** (Auto-registered):
- `jvm_memory_used_bytes{area="heap"}` - Current heap usage
- `jvm_memory_max_bytes{area="heap"}` - Max heap size
- `jvm_gc_pause_seconds_sum` - Total GC pause time
- `jvm_threads_live` - Current thread count
- `jvm_classes_loaded` - Loaded class count

**2. HTTP Metrics** (Runtime-specific):
- Request counts, durations, status codes
- Spring Boot: `http_server_requests_seconds_*`
- Tomcat/WildFly: Custom servlet metrics

**3. Container Metrics** (via cAdvisor):
- `container_memory_usage_bytes` - RSS + cache
- `container_cpu_usage_seconds_total` - CPU time

### Prometheus Scraping Architecture

**ServiceMonitor Pattern**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-sample-undertow
spec:
  selector:
    matchLabels:
      app: metrics-sample-undertow
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

**Flow**:
1. ServiceMonitor selects Service by label
2. Service selects Pods by label
3. Prometheus scrapes Pod endpoints every 30s
4. Metrics stored in Prometheus TSDB

**Port Strategy**:
- Undertow/Spring Boot/Tomcat: Metrics on application port (8080)
- WildFly: Metrics on management port (9990, separate Service required)

---

## Container Awareness Mechanisms

### JVM Flag: `-Xlog:os+container=info`

**Purpose**: Logs detected container limits at JVM startup

**Example Output**:
```
[0.001s][info][os,container] Memory Limit is: 536870912 (512.00M)
[0.001s][info][os,container] Memory Soft Limit is: Unlimited
[0.001s][info][os,container] CPU Shares is: -1
[0.001s][info][os,container] CPU Quota is: -1
[0.001s][info][os,container] CPU Period is: 100000
[0.001s][info][os,container] Active Processor Count: 2
```

**Use Cases**:
- Verify JVM reads cgroups correctly
- Debug heap sizing issues (did JVM see limit?)
- Compare cgroups v1 vs v2 parsing

### Heap Sizing: `-XX:MaxRAMPercentage`

**Algorithm** (simplified):
1. JVM reads cgroups `memory.limit_in_bytes` (v1) or `memory.max` (v2)
2. Calculates max heap = container limit × (MaxRAMPercentage / 100)
3. Honors explicit `-Xmx` if set (overrides percentage)

**Example**:
- Container limit: 512Mi = 536,870,912 bytes
- `MaxRAMPercentage=65.0`
- Max heap = 536,870,912 × 0.65 ≈ 349MB

**Why Not Use `-Xmx` Directly?**
- `-Xmx512m` hardcodes value (not dynamic)
- `-XX:MaxRAMPercentage=65.0` adapts to any container limit
- Enables same Dockerfile for different resource classes

### CPU Detection: `Runtime.getRuntime().availableProcessors()`

**Cgroups v1**:
- Reads `cpu.cfs_quota_us` and `cpu.cfs_period_us`
- Calculates vCPUs = quota / period
- Falls back to `cpuset.cpus` if quota unlimited

**Cgroups v2**:
- Reads `cpu.max` (combined quota + period)
- Falls back to `cpuset.cpus.effective`

**Application Integration**:
```java
int vCPUs = Runtime.getRuntime().availableProcessors();
int ioThreads = Math.min(2, vCPUs);  // Undertow
int workerThreads = ioThreads * 8;
```

**Override for Testing**:
```bash
-XX:ActiveProcessorCount=2  # Force JVM to report 2 CPUs regardless of cgroups
```

### Thread Pool Sizing Patterns

| Runtime | Formula | Environment Variable | Default |
|---------|---------|---------------------|---------|
| Undertow | IO threads = min(2, vCPUs)<br>Worker threads = IO × 8 | N/A (hardcoded) | 2 IO, 16 workers |
| Spring Boot | Configurable | `TOMCAT_MAX_THREADS` | 50 |
| Tomcat | Configurable | `TOMCAT_MAX_THREADS` | 100 |
| WildFly | Configurable | `JBOSS_MAX_THREADS` | 80 |

**Rationale**:
- **I/O-heavy** (web requests with DB calls): 2-4× vCPUs
- **CPU-bound** (computation): 1× vCPUs
- **Mixed**: Start at 2× vCPUs, tune based on queue depth

---

## Security Design Patterns

### OpenShift Restricted SCC Compliance

All deployments meet OpenShift's `restricted` Security Context Constraints:

```yaml
securityContext:
  runAsNonRoot: true                     # Pod and container level
  allowPrivilegeEscalation: false        # Prevent privilege escalation
  capabilities:
    drop: ["ALL"]                        # Drop all Linux capabilities
  seccompProfile:
    type: RuntimeDefault                 # Enable seccomp filtering
```

**Why Restricted SCC?**
- Default for OpenShift projects (no admin intervention needed)
- Enforces least privilege principle
- Compatible with multi-tenant clusters

### Non-Root User Pattern

All containers run as **UID 185** (`jboss` user in UBI images):

```dockerfile
USER 185
```

**Benefits**:
- Cannot write to most filesystem locations (read-only root filesystem possible)
- Limited process visibility (cannot see other users' processes)
- Reduced attack surface if container compromised

**OpenShift Random UID**:
- OpenShift may override UID (e.g., 1000680000)
- Images must support arbitrary UIDs (UBI images do)
- Home directory writable via `emptyDir` volume if needed

### No Privileged Ports

All services use **port 8080** (application) and **9990** (WildFly management):
- Ports > 1024 require no special privileges
- Non-root users can bind to these ports

---

## Design Decisions & Rationale

### Why Four Java Versions?

**Decision**: Support Java 11, 17, 21, and 23

**Rationale**:
- **Java 11**: Last Java 8 successor, widely used in legacy apps, LTS
- **Java 17**: Current LTS (Sep 2021), modern feature set, most common target
- **Java 21**: Latest LTS (Sep 2023), virtual threads, pattern matching
- **Java 23**: Latest release (Sep 2024), experimental features, forward-looking

**Alternative Considered**: Include Java 8
- **Rejected**: UBI 9 drops Java 8 support, Java 8 container awareness limited pre-8u191

### Why These Four Runtimes?

**Decision**: Undertow, Spring Boot, Tomcat, WildFly

**Rationale**:
- **Undertow**: Lightweight baseline (minimal footprint)
- **Spring Boot**: Industry standard, most popular
- **Tomcat**: Classic servlet container, mature ecosystem
- **WildFly**: Full Jakarta EE, subsystem architecture, enterprise features

**Alternatives Considered**:
- **Quarkus**: Native image support valuable but different paradigm (future addition)
- **Helidon**: Lightweight but less adoption than Spring Boot
- **Jetty**: Similar to Tomcat, less differentiation

### Why RAM Percentages (Not Fixed `-Xmx`)?

**Decision**: Use `-XX:MaxRAMPercentage=<percent>` instead of `-Xmx<size>`

**Rationale**:
- **Dynamic**: Adapts to any container memory limit without Dockerfile changes
- **Portable**: Same image works in dev (512Mi) and prod (2Gi)
- **Safe**: Ensures headroom for native memory (GC, JIT, threads, buffers)

**Alternative Considered**: Fixed `-Xmx`
- **Rejected**: Requires separate Dockerfiles per environment, error-prone

### Why Different Heap Percentages per Runtime?

| Runtime | MaxRAMPercentage | Memory Limit | Rationale |
|---------|------------------|--------------|-----------|
| Undertow | 65% | 512Mi | Minimal native overhead, leaves 35% for GC/JIT |
| Spring Boot | 70% | 768Mi | Framework overhead, but efficient |
| Tomcat | 70% | 768Mi | Standalone servlet overhead similar to Spring |
| WildFly | 65% | 1Gi | Large module system, native memory for subsystems |

**Formula**: Heap + Native + GC + JIT + Threads + Buffers ≤ Container Limit

### Why UBI 9 (Not Alpine or Debian)?

**Decision**: Red Hat Universal Base Images 9

**Rationale**:
- **OpenShift Native**: Pre-configured for OpenShift SCCs
- **Enterprise Support**: Red Hat subscription eligible
- **Security**: CVE patching, minimal attack surface
- **Compliance**: FIPS, FedRAMP-ready
- **OpenJDK Builds**: Official Red Hat OpenJDK distributions

**Alternative Considered**: Alpine Linux
- **Rejected**: musl libc compatibility issues with some Java libraries, smaller ecosystem

### Why Separate Dockerfiles per Java Version?

**Decision**: `Dockerfile.openjdk{11,17,21,23}` instead of ARG-based version switching

**Rationale**:
- **Clarity**: Each Dockerfile self-documenting (explicit base image)
- **Safety**: No accidental version mismatch (ARG typo builds wrong version)
- **Tooling**: CI/CD, BuildConfigs can target specific files
- **Versioning**: Git tracks each version's evolution separately

**Alternative Considered**: Single Dockerfile with `ARG JAVA_VERSION`
- **Rejected**: Complex logic for different base image patterns (UBI 8 vs 9), error-prone

### Why BuildConfig + ImageStream (Not External Registry Only)?

**Decision**: Provide OpenShift BuildConfig resources alongside Dockerfiles

**Rationale**:
- **Cluster-Native**: Build in cluster (no local Docker/Podman needed)
- **GitOps**: Automatic rebuilds on Git commits (ConfigChange trigger)
- **Security**: Base image updates trigger rebuilds (ImageChange trigger)
- **Convenience**: `oc start-build` simpler than local build + push

**Alternative Considered**: External CI/CD only (GitHub Actions)
- **Also Provided**: Both methods supported, BuildConfig preferred for OpenShift users

### Why Prometheus (Not OpenTelemetry)?

**Decision**: Micrometer + Prometheus for metrics

**Rationale**:
- **Maturity**: Prometheus de-facto standard for Kubernetes/OpenShift
- **Integration**: OpenShift includes Prometheus Operator
- **Simplicity**: Pull model, no collector setup needed
- **Ecosystem**: Grafana, alerting, PromQL well-established

**Alternative Considered**: OpenTelemetry
- **Future Addition**: OTEL support possible (Micrometer supports OTEL exporters)

---

## Technology Stack Summary

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| **Base Images** | Red Hat UBI 9 | Latest | Enterprise support, OpenShift native |
| **Java Versions** | OpenJDK | 11, 17, 21, 23 | Cover LTS + latest |
| **Build Tool** | Apache Maven | 3.6+ | Java ecosystem standard |
| **Metrics Facade** | Micrometer | 1.10+ | Vendor-neutral metrics API |
| **Metrics Format** | Prometheus | N/A | Kubernetes standard |
| **HTTP Servers** | Undertow, Tomcat, Embedded Tomcat, WildFly | Latest stable | Diverse runtime comparison |
| **Container Runtime** | Podman / Docker | 20+ | OCI-compliant |
| **Orchestration** | OpenShift | 4.x | Enterprise Kubernetes |
| **CI/CD** | GitHub Actions | N/A | Automated builds |

---

## Next Steps for Contributors

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:
- Adding new runtime samples
- Creating experiment scenarios
- Proposing architecture changes
- Testing requirements

For deployment procedures, see [DEPLOYMENT.md](DEPLOYMENT.md).  
For troubleshooting, see [TESTING.md](TESTING.md).  
For version updates, see [VERSIONS.md](VERSIONS.md).  
