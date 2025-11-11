# Example Scenario: Heap Sizing Comparison Across OpenJDK Versions

## Goal
Compare default heap ergonomics and tuned heap configurations across OpenJDK 11, 17, 21, and 23 under identical container memory limits.

## Setup

### Container Configuration
- Memory limit: 512Mi
- CPU limit: 500m (0.5 CPU)
- Runtime: Undertow (minimal overhead)

### Test Configurations
1. **Baseline**: Default JVM heap sizing (no explicit flags)
2. **Tuned**: `-XX:MaxRAMPercentage=65.0 -XX:InitialRAMPercentage=50.0`

## Hypothesis
Newer OpenJDK versions (17+) will demonstrate:
- More accurate container limit detection
- Better heap sizing ergonomics
- Reduced GC pressure during warmup

## Procedure

### 1. Deploy Baseline Configuration

Create modified deployment without explicit heap flags:

```bash
# Copy baseline template
cp baseline-deployment.yaml /tmp/test-deployment.yaml

# Deploy all versions
for VERSION in 11 17 21 23; do
  sed "s/VERSION/${VERSION}/g" /tmp/test-deployment.yaml | oc apply -f -
done
```

### 2. Capture Baseline Metrics

Wait 10 minutes for warmup, then capture:

```bash
# Using provided script
../scripts/capture-baselines.sh

# Or manually
for POD in $(oc get pods -l scenario=heap-comparison -o name); do
  POD_NAME=$(basename ${POD})
  oc exec ${POD_NAME} -- java -Xlog:os+container=info -XX:+PrintFlagsFinal -version \
    > results/${POD_NAME}-baseline.txt 2>&1
done
```

### 3. Record Prometheus Metrics

Query over 1-hour window:

```promql
# Max heap configured
max_over_time(jvm_memory_max_bytes{area="heap", scenario="heap-comparison"}[1h])

# Heap usage 95th percentile
quantile_over_time(0.95, jvm_memory_used_bytes{area="heap", scenario="heap-comparison"}[1h])

# GC pause count
increase(jvm_gc_pause_seconds_count{scenario="heap-comparison"}[1h])

# Total GC pause time
increase(jvm_gc_pause_seconds_sum{scenario="heap-comparison"}[1h])
```

### 4. Deploy Tuned Configuration

Update deployments with explicit heap flags and redeploy.

### 5. Capture Tuned Metrics

Repeat steps 2-3 with tuned configuration.

## Expected Results

### Baseline (No explicit flags)

| Version | Max Heap (Mi) | Initial Heap (Mi) | GC Count (1h) | Total GC Time (s) |
|---------|---------------|-------------------|---------------|-------------------|
| 11      | ~256          | ~8                | TBD           | TBD               |
| 17      | ~256          | ~8                | TBD           | TBD               |
| 21      | ~256          | ~8                | TBD           | TBD               |
| 23      | ~256          | ~8                | TBD           | TBD               |

### Tuned (MaxRAMPercentage=65, InitialRAMPercentage=50)

| Version | Max Heap (Mi) | Initial Heap (Mi) | GC Count (1h) | Total GC Time (s) |
|---------|---------------|-------------------|---------------|-------------------|
| 11      | ~333          | ~256              | TBD           | TBD               |
| 17      | ~333          | ~256              | TBD           | TBD               |
| 21      | ~333          | ~256              | TBD           | TBD               |
| 23      | ~333          | ~256              | TBD           | TBD               |

## Observations

### Container Awareness
Extract from baseline captures:

```bash
grep -E "(container|Memory Limit|CPU)" results/*-baseline.txt
```

Expected output showing detection:
```
OSContainer::init: Initializing Container Support
Memory Limit is: 536870912
Active Processor Count: 1
```

### Heap Calculation
```bash
grep -E "(MaxHeapSize|InitialHeapSize)" results/*-baseline.txt
```

### GC Algorithm
```bash
grep "UseG1GC\|UseParallelGC\|UseSerialGC" results/*-baseline.txt
```

## Conclusions

*To be filled after running experiment*

Key findings:
1. Version differences in heap sizing logic
2. Impact of InitialRAMPercentage on warmup GC frequency
3. Trade-offs between heap size and native memory headroom

## Artifacts

All results stored in `results/`:
- `*-baseline.txt`: JVM flag dumps
- `metrics-baseline.csv`: Exported Prometheus data
- `metrics-tuned.csv`: Exported Prometheus data
- `analysis.ipynb`: Jupyter notebook with visualizations (optional)

## References

- [Memory Tuning Overhaul](https://developers.redhat.com/articles/2023/03/07/overhauling-memory-tuning-openjdk-containers-updates)
- Parent `.github/copilot-instructions.md` section 5 (Memory Tuning Essentials)
