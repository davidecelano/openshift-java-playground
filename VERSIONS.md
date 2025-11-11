# Image Version Reference

This file documents the specific container image versions used across all samples for reproducibility and security compliance.

## Red Hat UBI OpenJDK Images

All samples use Red Hat Universal Base Images (UBI) with pinned versions to ensure reproducible builds and predictable behavior across OpenShift environments.

### Version Strategy

- **Tag Format**: `MAJOR.MINOR` (e.g., `1.21`)
- **Rationale**: Provides stability while receiving security updates within the same stream
- **Update Policy**: Manual updates required; review release notes before updating

### Current Versions (as of November 2025)

| Java Version | Base OS | Builder Image | Runtime Image | Status |
|--------------|---------|---------------|---------------|--------|
| OpenJDK 11 | UBI 8 | `registry.access.redhat.com/ubi8/openjdk-11:1.21` | `registry.access.redhat.com/ubi8/openjdk-11-runtime:1.21` | **DEPRECATED** - Migrate to 17/21 |
| OpenJDK 17 | UBI 8 | `registry.access.redhat.com/ubi8/openjdk-17:1.21` | `registry.access.redhat.com/ubi8/openjdk-17-runtime:1.21` | **Stable LTS** |
| OpenJDK 21 | UBI 9 | `registry.access.redhat.com/ubi9/openjdk-21:1.21` | `registry.access.redhat.com/ubi9/openjdk-21-runtime:1.21` | **Latest LTS (Recommended)** |
| OpenJDK 23 | UBI 9 | `registry.access.redhat.com/ubi9/openjdk-21:1.21` | `registry.access.redhat.com/ubi9/openjdk-21-runtime:1.21` | Uses Java 21 base (no native 23 image) |

### Special Cases

#### Tomcat Samples
Tomcat samples use a two-stage approach:
1. **Builder**: Standard UBI OpenJDK image for Maven builds
2. **Runtime**: `registry.access.redhat.com/ubi9/ubi-minimal:9.5` + manual JDK installation for smaller footprint

#### WildFly Samples
WildFly samples use:
1. **Builder**: Standard UBI OpenJDK image for Maven builds
2. **Runtime**: Official WildFly images from Quay.io with version pinning:
   - Java 11: `quay.io/wildfly/wildfly:27.0.1.Final-jdk11`
   - Java 17: `quay.io/wildfly/wildfly:31.0.1.Final-jdk17`
   - Java 21/23: `quay.io/wildfly/wildfly:31.0.1.Final-jdk21`

## Red Hat Container Catalog References

- **OpenJDK 11**: https://catalog.redhat.com/software/containers/ubi8/openjdk-11/5dd6a4b45a13461646f677f4
- **OpenJDK 17**: https://catalog.redhat.com/software/containers/ubi8/openjdk-17/61ee7c26ed74fbb5f6c800e7
- **OpenJDK 21**: https://catalog.redhat.com/software/containers/ubi9/openjdk-21/6501574c5a13467447f8e844
- **UBI Minimal**: https://catalog.redhat.com/software/containers/ubi9/ubi-minimal/615bd9b4075b022acc111bf5

## Lifecycle Information

From [Red Hat OpenJDK Support Policy](https://access.redhat.com/articles/1299013):

- **OpenJDK 11**: End of Support October 31, 2024 (Extended with ELS to October 31, 2027)
- **OpenJDK 17**: End of Support October 31, 2027
- **OpenJDK 21**: End of Support December 31, 2029

**Note**: Red Hat only provides LTS versions (8, 11, 17, 21). Non-LTS versions like OpenJDK 23 should use the latest LTS base image.

## Update Procedure

### Standard Update (Modify Defaults)

When updating image versions across the repository:

1. Check [Red Hat Container Catalog](https://catalog.redhat.com/software/containers/search) for new releases
2. Review release notes and security advisories
3. Update version references in this file
4. Update default ARG values in all Dockerfiles (16 files across 4 runtimes)
5. Update buildArgs values in BuildConfig manifests (`openshift/buildconfig-*.yaml`)
6. Test builds locally: `./scripts/build-all.sh`
7. Test deployments: `./scripts/deploy-all.sh`
8. Run baseline captures: `./scripts/capture-baselines.sh`
9. Commit changes with clear version update message

### Dynamic Override (Per-Build)

Override versions without modifying files using build arguments:

**Local Builds (Podman/Docker)**:
```bash
# Override single runtime
cd metrics-sample-undertow
podman build -f Dockerfile.openjdk17 \
  --build-arg BUILDER_IMAGE=registry.../openjdk-17:1.22 \
  --build-arg RUNTIME_IMAGE=registry.../openjdk-17-runtime:1.22 \
  -t myimage:tag .

# Override via build-all.sh script
BUILDER_IMAGE_17=registry.../openjdk-17:1.22 \
RUNTIME_IMAGE_17=registry.../openjdk-17-runtime:1.22 \
./scripts/build-all.sh

# Override Tomcat version
TOMCAT_VERSION=10.1.16 ./scripts/build-all.sh

# Override WildFly image
WILDFLY_IMAGE_21=quay.io/wildfly/wildfly:31.0.2.Final-jdk21 \
./scripts/build-all.sh
```

**OpenShift Builds**:
```bash
# Edit BuildConfig to change buildArgs values
oc edit buildconfig metrics-undertow-openjdk17

# Or patch specific build args
oc patch buildconfig metrics-undertow-openjdk17 --type=json -p='[
  {"op": "replace", "path": "/spec/strategy/dockerStrategy/buildArgs/0/value", 
   "value": "registry.access.redhat.com/ubi8/openjdk-17:1.22"}
]'

# Trigger build with updated args
oc start-build metrics-undertow-openjdk17
```

**Available Build Arguments**:

| Runtime | Arg Name | Description | Example Override |
|---------|----------|-------------|------------------|
| All | `BUILDER_IMAGE` | Maven build stage base | `ubi8/openjdk-17:1.22` |
| Undertow, Spring Boot | `RUNTIME_IMAGE` | Application runtime base | `ubi8/openjdk-17-runtime:1.22` |
| Tomcat | `RUNTIME_BASE` | Minimal UBI base | `ubi9/ubi-minimal:9.6` |
| Tomcat | `TOMCAT_VERSION` | Apache Tomcat version | `10.1.16` |
| WildFly | `WILDFLY_IMAGE` | WildFly runtime image | `wildfly:31.0.2.Final-jdk17` |

## Security Considerations

- Monitor [Red Hat Security Advisories](https://access.redhat.com/security/security-updates/) for CVEs
- Subscribe to UBI image notifications in Red Hat Container Catalog
- Plan regular version reviews (quarterly recommended)
- Test thoroughly in non-production before updating production scenarios

## Image Tag Philosophy

**Why not `:latest`?**
- Breaks reproducibility (builds today ≠ builds tomorrow)
- Introduces unpredictable security/behavior changes
- Complicates compliance audits and troubleshooting

**Why not full SHA or specific build timestamps?**
- Misses critical security patches within the same stream
- Requires frequent manual updates
- Increases maintenance burden for experimental repository

**Why `MAJOR.MINOR` tags?**
- Balance between stability and security updates
- Predictable behavior within version stream
- Red Hat maintains compatibility within streams
- Suitable for reproducible experiments with reasonable update windows