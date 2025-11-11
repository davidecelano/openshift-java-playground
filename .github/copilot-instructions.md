# Copilot Instructions: OpenShift Java Container Scenarios

## 1. Purpose & Scope
Resource hub for reproducible experiments of Java applications on OpenShift: metrics, JVM options, container ergonomics across Java versions, cgroups v1/v2 behavior, scaling & tuning.
Scope: Focus exclusively on OpenJDK (community / Red Hat builds). Exclude Oracle commercial-only features or flags; document only behavior available in standard OpenJDK distributions.

## 2. Scenario Layout Convention
Each experiment lives in its own top-level directory with: `README.md` (goal, setup, expected observations), scripts/manifests, Java snippet or app, optional `results/` artifacts.
Example dirs: `metrics/`, `java-options/`, `cgroups-compat/`, `tuning-cgroups-v2/`, `cpu-scaling/`.

**Build Strategy**: Prefer OpenShift BuildConfig as primary build method (source-to-image from Git). GitHub Actions available as secondary manual-trigger option for local registry workflows. All samples include both `openshift/` (BuildConfigs) and `Dockerfiles` (local builds).

**Version Pinning**: All base images use explicit version tags (never `:latest`). See `VERSIONS.md` for current image versions and update procedures.

## 3. Standard Scenario Workflow
1. Declare container limits (memory, CPU) & Java version in README.
2. Capture baseline: `java -Xlog:os+container=info -XX:+PrintFlagsFinal -version > baseline.txt`.
3. Run tuned variant (adjust flags). Record deltas.
4. Add OpenShift manifest (`Deployment`/`BuildConfig`) with resource requests/limits.
5. Document metrics (heap %, GC pauses, thread counts) and conclusions.

## 4. Version / Container Awareness Matrix (Summary)
Java 8 pre-8u191: limited container parsing; manual flags often needed.
Java 8u191+ / 10+: container awareness default, prefer percentage heap flags.
Java 8u372: cgroups v2 support improvements.
Java 11–17: stable container heuristics; `-Xlog:os+container=info` for visibility.

## 5. Memory Tuning Essentials
Default max heap = fraction of container memory (ergonomics vary by version). Prefer: `-XX:MaxRAMPercentage=<p>` (commonly 60–70) & optional `-XX:InitialRAMPercentage=<p>` for startup stability. Avoid legacy `MaxRAMFraction` except in comparison scenarios. Keep headroom for metaspace/JIT/native (target heap ≤ 75% of limit). Adjust free ratios (`MinHeapFreeRatio`/`MaxHeapFreeRatio`) to shape GC growth.

## 6. CPU & Threads
JVM reads quota/period & cpuset; override for deterministic tests with `-XX:ActiveProcessorCount=<n>`. Size thread pools to effective container CPUs, not host cores. Track any app-level env var (e.g., `JBOSS_MAX_THREADS`) and justify formula (commonly 2–4× vCPUs for I/O heavy workloads).

## 7. Cgroups v1 vs v2
v1 = multiple controller files; v2 = unified hierarchy with clearer memory & swap semantics. Validate parsing via `-Xlog:os+container=info`. Design scenarios comparing heap ergonomics and GC behavior under identical limits.

## 8. Metrics & Observability Patterns
Expose JVM metrics (Micrometer/Prometheus) under `/metrics`. Record: heap used vs limit, GC pause distribution, live thread count, class/metaspace usage. For stress tests include before/after tuning tables. Consider adding sample Prometheus queries in scenario README.

## 9. Deployment Manifests Patterns
Provide minimal `Deployment` YAML with explicit `resources.requests` & `resources.limits`. Annotate chosen heap % rationale. Optional: sidecar scraper or ServiceMonitor example.

**Security Context Requirements**: All deployments must include OpenShift-compatible security contexts:
- `securityContext.runAsNonRoot: true` (pod and container level)
- `securityContext.allowPrivilegeEscalation: false`
- `securityContext.capabilities.drop: ["ALL"]`
- `securityContext.seccompProfile.type: RuntimeDefault`

These settings ensure compatibility with OpenShift's restricted Security Context Constraints (SCC) and follow security best practices.

**BuildConfig Pattern**: Include OpenShift `BuildConfig` resources in `openshift/` subdirectory for each sample. Use `strategy.dockerStrategy` with Git source pointing to repository. Create corresponding `ImageStream` resources with `lookupPolicy.local: false` for automatic updates.

## 10. Recommended Flag Cheat Sheet
| Goal | Flags | Notes |
|------|-------|-------|
| Balanced memory | `-XX:MaxRAMPercentage=65` | Leaves native/GC headroom |
| Faster stable startup | `-XX:InitialRAMPercentage=50 -XX:MaxRAMPercentage=65` | Fewer early expansions |
| CPU scaling test | `-XX:ActiveProcessorCount=2` | Force smaller core view |
| GC pressure | `-XX:MaxRAMPercentage=75 -XX:MinHeapFreeRatio=20 -XX:MaxHeapFreeRatio=30` | Stress allocation/GC |
| Legacy compare | `-XX:MaxRAMFraction=2` | Show migration path |
| Container parse audit | `-Xlog:os+container=info` | Log detected limits |

## 11. Pitfalls
Oversized heap triggers Kubernetes OOMKill (external). Host core count misuse inflates threads → context switch overhead. Near-maximum heap percentages starve native buffers (network, NIO). Ignoring metaspace/JIT leads to fragmentation. Swap expectations unreliable in containers.

## 12. Implementing New Tuning Scenario
Create dir (e.g., `tuning-cgroups-v2/`). Add baseline & tuned run scripts. Table: limits, heap flags, observed max RSS, GC stats. Annotate Java & container runtime versions. Include conclusions on trade-offs.

## 13. Runtime Profiles (WildFly, Tomcat, Spring Boot)
Concise container-focused tuning guidance; use these when designing scenario directories.

### WildFly (JBoss EAP style)
- Threading: Undertow IO threads ≈ min(2, vCPUs) by default; worker threads often ≈ 8 * IO threads. Cap via env (`JBOSS_MAX_THREADS`) or subsystem config; size near 2–4× vCPUs for I/O heavy loads, lower for CPU-bound.
- Memory: Extra native/metaspace for modules & classloading; reserve ≥ 5–10% more headroom vs plain servlet container. Heap target ≤ 65–70% of limit.
- Flags: Combine `-XX:InitialRAMPercentage=50 -XX:MaxRAMPercentage=65` for stable boot times under constrained memory.
- Metrics: Expose management & app metrics separately if comparing thread saturation vs GC.

### Tomcat
- Connector threads: `maxThreads` (HTTP) is primary concurrency lever; default often 200. In containers, start with 4 × vCPUs for mixed I/O and adjust from observed request queue length & CPU utilization.
- Embedded vs standalone: For Spring Boot embedded Tomcat use `server.tomcat.max-threads`; for standalone edit `server.xml`. Keep consistent scenario docs.
- Memory: Lower metaspace overhead; can push heap a little higher (e.g., 70–75%) if GC pauses acceptable. Still retain native buffers for sockets/NIO.
- Env vars: Use `CATALINA_OPTS` for JVM flags; keep reproducible script capturing baseline flags.

### Spring Boot (Embedded Tomcat/Undertow/Netty)
- Startup profiling: Use `-XX:InitialRAMPercentage` to pre-size heap reducing warmup GC for large dependency graphs.
- Thread tuning:
	- Tomcat: `server.tomcat.max-threads=<n>` (apply same sizing heuristics as above).
	- Undertow: Adjust `server.undertow.io-threads` (≈ vCPUs) and `server.undertow.worker-threads` (2–8× IO threads).
	- Netty: EventLoop count ≈ vCPUs; rarely oversize.
- Metrics: Enable Actuator + Prometheus endpoint (`/actuator/prometheus`). Record heap, threads, GC, HTTP throughput before/after tuning.
- Native memory: Boot’s layered jars add minor startup footprint; still leave margin for JIT & direct buffers.

### Common Runtime Scenario Pattern
1. Baseline run capturing: `java -Xlog:os+container=info -XX:+PrintFlagsFinal -version` and runtime-specific thread/connector settings.
2. Tuned run adjusting heap %, thread counts, and optionally `ActiveProcessorCount`.
3. Result table: limits, heap %, peak RSS, request throughput (or synthetic load), average/95p GC pause, thread saturation indicators.

## 14. References (Key Points)
OpenJDK 8–13 man pages: evolution to percentage flags & container defaults. OpenShift scaling blog: thread pool/resource alignment. Docker support Java 8 article: early container limitations. Data Grid tuning: ratios & GC implications. OpenJDK 17 container awareness: logging improvements. OpenJDK 8u372 blog: cgroups v2 parsing. Memory tuning overhaul (OpenJDK): shift to clearer percentage semantics. Container awareness usage article: validation workflow.

## 15. Contributing Patterns
Keep experiments isolated. Prefer scripts over manual steps. Provide reproducible commands. Summarize findings in a short results section. Link references used.

## 16. OpenShift Build & Deploy Pattern
Primary build method uses OpenShift BuildConfig resources for native cluster builds from Git sources.

### BuildConfig Structure
- Location: `<sample-dir>/openshift/buildconfig-openjdk<version>.yaml`
- Source: Git repository reference with contextDir
- Strategy: Docker with explicit Dockerfile path
- Output: ImageStreamTag in project-local ImageStream
- Triggers: ConfigChange + ImageChange for automatic rebuilds

### Build Workflow
1. Create ImageStream: `oc apply -f openshift/imagestream.yaml`
2. Create BuildConfigs: `oc apply -f openshift/buildconfig-*.yaml`
3. Trigger build: `oc start-build metrics-undertow-openjdk17`
4. Monitor: `oc logs -f bc/metrics-undertow-openjdk17`
5. Deploy: Update deployment to reference ImageStreamTag

### Version Control
Images built in OpenShift reference specific Dockerfile versions pinned in `VERSIONS.md`. BuildConfig `dockerStrategy.forcePull: true` ensures fresh base image pulls on each build.

---
Refine or extend by adding scenario directories and updating this file when new container behaviors emerge.
