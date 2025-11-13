# Version Management Guide

📚 **Documentation**: [README](README.md) | [Quick Start](QUICKSTART.md) | [Deployment](DEPLOYMENT.md) | [Testing](TESTING.md) | [Implementation](IMPLEMENTATION.md) | [Versions](VERSIONS.md) | [Contributing](CONTRIBUTING.md)

---

This guide documents procedures for updating container base images, application server versions, and dependencies. For current version matrix, see [VERSIONS.md](VERSIONS.md).

## Table of Contents
- [Overview](#overview)
- [Update Procedures](#update-procedures)
  - [Java Base Images (UBI)](#java-base-images-ubi)
  - [Application Server Versions](#application-server-versions)
  - [Maven Dependencies](#maven-dependencies)
- [Testing Checklist](#testing-checklist)
- [Rollback Procedures](#rollback-procedures)
- [Update Cadence](#update-cadence)

---

## Overview

### Version Management Strategy

This repository uses **pinned versions** for all base images and dependencies to ensure:
- **Reproducibility**: Same Dockerfile builds identically across time
- **Security**: Explicit updates with CVE review, not automatic
- **Testing**: Validation before promoting version changes

### Version Locations

| Component | Location | Override Method |
|-----------|----------|-----------------|
| **Java Base Images** | `Dockerfile.openjdk*` ARG directives | `--build-arg` or environment variables |
| **Tomcat Version** | `Dockerfile.openjdk*` ARG `TOMCAT_VERSION` | `--build-arg TOMCAT_VERSION=x.y.z` |
| **WildFly Version** | `Dockerfile.openjdk*` ARG `WILDFLY_IMAGE` | `--build-arg WILDFLY_IMAGE=...` |
| **Spring Boot Version** | `pom.xml` parent version | Edit `pom.xml` |
| **Maven Dependencies** | `pom.xml` dependencies section | Edit `pom.xml` |

---

## Update Procedures

### Java Base Images (UBI)

#### When to Update
- **Security vulnerabilities**: Red Hat CVE announcements
- **New UBI minor versions**: Quarterly releases (e.g., UBI 9.5 → 9.6)
- **New Java patch versions**: Monthly releases (e.g., `:1.21` → `:1.22`)

#### Update Steps

**1. Check Release Notes**
```bash
# Red Hat OpenJDK release notes
# https://access.redhat.com/documentation/en-us/openjdk/

# UBI release notes
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/9.5_release_notes/
```

**2. Update Version References**

Edit `VERSIONS.md` first (single source of truth):
```markdown
| OpenJDK 17 | UBI 9 | `registry.access.redhat.com/ubi9/openjdk-17:1.22` | ...
```

**3. Update Dockerfiles (Optional - ARG defaults)**

If updating default ARG values in Dockerfiles:
```dockerfile
# Before
ARG BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.21

# After
ARG BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.22
```

**Files to update** (if changing defaults):
- `metrics-sample-undertow/Dockerfile.openjdk{11,17,21,23}`
- `metrics-sample-springboot/Dockerfile.openjdk{17,21,23}`
- `metrics-sample-tomcat/Dockerfile.openjdk{11,17,21,23}`
- `metrics-sample-wildfly/Dockerfile.openjdk{11,17,21,23}`

**4. Update BuildConfigs (Optional - defaults)**

If updating BuildConfig `buildArgs` defaults:
```yaml
strategy:
  dockerStrategy:
    buildArgs:
      - name: BUILDER_IMAGE
        value: "registry.access.redhat.com/ubi9/openjdk-17:1.22"
```

**Files to update** (if changing defaults):
- `metrics-sample-*/openshift/buildconfig-openjdk*.yaml`

**5. Test Build with New Version**

Using ARG override (no file changes):
```bash
# Test single sample
cd metrics-sample-undertow
podman build -f Dockerfile.openjdk17 \
  --build-arg BUILDER_IMAGE=registry.access.redhat.com/ubi9/openjdk-17:1.22 \
  --build-arg RUNTIME_IMAGE=registry.access.redhat.com/ubi9/openjdk-17-runtime:1.22 \
  -t test:latest .

# Test all samples
export BUILDER_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17:1.22
export RUNTIME_IMAGE_17=registry.access.redhat.com/ubi9/openjdk-17-runtime:1.22
./scripts/build-all.sh
```

**6. Run Validation Suite**

See [Testing Checklist](#testing-checklist) below.

**7. Update Documentation**

If changing defaults, update references in:
- `VERSIONS.md` (always update, single source of truth)
- `README.md` (if mentioning specific versions)
- `DEPLOYMENT.md` (if version-specific instructions)

**8. Commit Changes**

```bash
git add VERSIONS.md Dockerfile* buildconfig*.yaml
git commit -m "chore: update OpenJDK 17 base images to 1.22

- Update UBI 9 OpenJDK 17 from 1.21 to 1.22
- Includes security fixes: CVE-YYYY-XXXXX
- All 15 Dockerfiles build successfully
- Runtime tests: 4/4 PASSED"
```

---

### Application Server Versions

#### Tomcat Updates

**When to Update**:
- Security vulnerabilities in Tomcat
- New stable releases (10.1.x series)
- Major version upgrades (10.1 → 11.0, requires Java EE → Jakarta EE migration)

**Update Steps**:

**1. Check Compatibility**
- Tomcat 10.1.x requires Java 11+
- Tomcat 11.0.x requires Java 17+

**2. Update Default ARG in Dockerfiles**
```dockerfile
# metrics-sample-tomcat/Dockerfile.openjdk17
ARG TOMCAT_VERSION=10.1.49  # ← Update this line
```

**3. Test Download Link**
```bash
TOMCAT_VERSION=10.1.50
curl -I "https://archive.apache.org/dist/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
```

**4. Build & Test**
```bash
cd metrics-sample-tomcat
podman build -f Dockerfile.openjdk17 --build-arg TOMCAT_VERSION=10.1.50 -t test:latest .
podman run -d -p 8080:8080 test:latest
curl http://localhost:8080/health
```

**5. Update All Tomcat Dockerfiles**

Files: `metrics-sample-tomcat/Dockerfile.openjdk{11,17,21,23}`

---

#### WildFly Updates

**When to Update**:
- New WildFly releases (monthly cadence)
- Security patches
- Jakarta EE version upgrades

**Update Steps**:

**1. Check Java Version Requirements**
- WildFly 34.x: Java 11-17
- WildFly 35-37.x: Java 11-21
- WildFly 38.x+: Java 17-21 (Java 11 support dropped)

**2. Update Default ARG in Dockerfiles**
```dockerfile
# metrics-sample-wildfly/Dockerfile.openjdk17
ARG WILDFLY_IMAGE=quay.io/wildfly/wildfly:38.0.1.Final-jdk17
```

**3. Test Image Availability**
```bash
podman pull quay.io/wildfly/wildfly:38.0.1.Final-jdk17
```

**4. Build & Test**
```bash
cd metrics-sample-wildfly
podman build -f Dockerfile.openjdk17 \
  --build-arg WILDFLY_IMAGE=quay.io/wildfly/wildfly:38.0.1.Final-jdk17 \
  -t test:latest .
podman run -d -p 8080:8080 -p 9990:9990 test:latest
curl http://localhost:9990/metrics
```

**5. Update All WildFly Dockerfiles**

Files: `metrics-sample-wildfly/Dockerfile.openjdk{11,17,21,23}`

**Note**: Maintain version consistency:
- Java 11 samples → WildFly 34.x (last version supporting Java 11)
- Java 17/21/23 samples → WildFly 38.x+ (current stable)

---

#### Spring Boot Updates

**When to Update**:
- Security vulnerabilities in Spring Boot
- New minor/patch releases (3.x.y)
- Dependency updates (embedded Tomcat, Micrometer)

**Update Steps**:

**1. Update pom.xml Parent Version**
```xml
<!-- metrics-sample-springboot/pom.xml -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.1</version>  <!-- Update this version -->
</parent>
```

**2. Review Release Notes**
- https://github.com/spring-projects/spring-boot/releases

**3. Test Build Locally**
```bash
cd metrics-sample-springboot
mvn clean package
java -jar target/metrics-sample-springboot-1.0.0.jar
```

**4. Test Container Build**
```bash
podman build -f Dockerfile.openjdk21 -t test:latest .
```

---

### Maven Dependencies

#### Micrometer Updates

**When to Update**:
- Security vulnerabilities
- New Prometheus metric types
- Bug fixes

**Files to Update**:
- `metrics-sample-undertow/pom.xml`
- `metrics-sample-tomcat/pom.xml`
- `metrics-sample-wildfly/pom.xml`

**Update Steps**:

**1. Check Current Version**
```bash
grep "micrometer-" metrics-sample-undertow/pom.xml
```

**2. Update Dependency Versions**
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    <version>1.13.0</version>  <!-- Update version -->
</dependency>
```

**3. Test All Affected Samples**
```bash
for sample in undertow tomcat wildfly; do
    cd metrics-sample-$sample
    mvn clean test
    cd ..
done
```

---

## Testing Checklist

Use this checklist after **any version update** before committing changes.

### Phase 1: Build Validation

- [ ] **Run quick validation script**
  ```bash
  ./scripts/quick-validate-builds.sh
  ```

- [ ] **Verify all 15 Dockerfiles build successfully**
  - [ ] Undertow: openjdk11, 17, 21, 23
  - [ ] Spring Boot: openjdk17, 21, 23
  - [ ] Tomcat: openjdk11, 17, 21, 23
  - [ ] WildFly: openjdk11, 17, 21, 23

- [ ] **Check build output for warnings**
  - No deprecated Maven dependencies
  - No security warnings in base images

### Phase 2: Runtime Validation

- [ ] **Run runtime validation script**
  ```bash
  ./scripts/validate-runtime.sh
  ```

- [ ] **Test one sample per runtime**
  - [ ] Undertow: Health endpoint, metrics endpoint
  - [ ] Spring Boot: Actuator health, Prometheus metrics
  - [ ] Tomcat: HTTP 200/404, version string in response
  - [ ] WildFly: Port 9990 metrics, `base_` namespace

- [ ] **Verify container awareness logs**
  ```bash
  podman run test:latest 2>&1 | grep "os,container"
  ```

### Phase 3: BuildConfig Validation

- [ ] **Validate BuildConfig YAML syntax**
  ```bash
  ./scripts/validate-buildconfigs.sh
  ```

- [ ] **Test ARG overrides (one per runtime)**
  - [ ] Undertow: `BUILDER_IMAGE` override
  - [ ] Spring Boot: `RUNTIME_IMAGE` override
  - [ ] Tomcat: `TOMCAT_VERSION` override
  - [ ] WildFly: `WILDFLY_IMAGE` override

### Phase 4: OpenShift Deployment (Optional)

- [ ] **Run OpenShift deployment validation**
  ```bash
  export OPENSHIFT_NAMESPACE=java-metrics-test
  export SAMPLE=undertow
  export JAVA_VERSION=17
  ./scripts/validate-openshift-deployment.sh
  ```

- [ ] **Verify full workflow**
  - [ ] ImageStream creation
  - [ ] BuildConfig creation
  - [ ] Build trigger and completion
  - [ ] ImageStreamTag created
  - [ ] Deployment from ImageStreamTag
  - [ ] Pod running
  - [ ] Endpoints responding

### Phase 5: Documentation Validation

- [ ] **Update VERSIONS.md with new versions**
- [ ] **Update CHANGELOG.md (if exists)**
- [ ] **Update deployment examples if version-specific**
- [ ] **Check all cross-references still valid**

### Phase 6: Security Review

- [ ] **Check for CVEs in new versions**
  - Red Hat CVE database: https://access.redhat.com/security/security-updates/cve
  - Apache Tomcat security: https://tomcat.apache.org/security.html
  - WildFly security: https://wildfly.org/news/

- [ ] **Scan container images**
  ```bash
  podman build -f Dockerfile.openjdk17 -t scan-test:latest .
  # Use organizational scanning tools (e.g., Trivy, Clair, Snyk)
  ```

---

## Rollback Procedures

If a version update causes issues in production:

### Immediate Rollback (OpenShift)

**1. Rollback Deployment**
```bash
oc rollout undo deployment/metrics-sample-undertow-openjdk17
```

**2. Verify Rollback**
```bash
oc rollout status deployment/metrics-sample-undertow-openjdk17
oc get pods -l app=metrics-sample-undertow
```

### Git Rollback (Source Changes)

**1. Identify Last Good Commit**
```bash
git log --oneline VERSIONS.md
git log --oneline metrics-sample-*/Dockerfile*
```

**2. Revert Specific Commit**
```bash
git revert <commit-hash>
git push origin main
```

**3. Rebuild Images**
```bash
./scripts/build-all.sh
./scripts/push-all.sh
```

### BuildConfig Rollback (OpenShift)

**1. Edit BuildConfig to Previous Version**
```bash
oc edit buildconfig metrics-undertow-openjdk17
# Change buildArgs back to previous version
```

**2. Trigger New Build**
```bash
oc start-build metrics-undertow-openjdk17
```

---

## Update Cadence

### Recommended Schedule

| Component | Frequency | Trigger |
|-----------|-----------|---------|
| **Java Base Images (Security)** | As needed | Red Hat CVE announcements |
| **Java Base Images (Routine)** | Monthly | New UBI patch releases |
| **Tomcat** | Quarterly | New stable releases |
| **WildFly** | Quarterly | Major releases (skip minor) |
| **Spring Boot** | Quarterly | New minor versions (3.x.0) |
| **Maven Dependencies** | Semi-annually | Major Micrometer releases |

### Process

**1. Monitor Release Channels**
- Red Hat Customer Portal: Security advisories
- GitHub: Watch repositories for releases
- Mailing lists: Subscribe to project announcements

**2. Triage Updates**
- **Critical security**: Update within 7 days
- **High priority**: Update within 30 days
- **Routine maintenance**: Quarterly cycle

**3. Batch Compatible Updates**
- Group updates by sample (e.g., all Undertow Dockerfiles together)
- Test as a batch, commit as a batch
- Use single PR for related updates

**4. Communicate Changes**
- Update VERSIONS.md with rationale
- Add notes in commit messages
- Document breaking changes in deployment instructions

---

## Version Compatibility Matrix

### Java Version Constraints

| Application Server | Minimum Java | Maximum Java | Notes |
|--------------------|--------------|--------------|-------|
| **Undertow** | 11 | 23 | No restrictions, lightweight runtime |
| **Spring Boot 3.4.x** | 17 | 23 | Requires Java 17+ (Spring Framework 6) |
| **Tomcat 10.1.x** | 11 | 23 | Jakarta EE 9 (javax → jakarta migration) |
| **Tomcat 11.0.x** | 17 | 23 | Jakarta EE 10, requires Java 17+ |
| **WildFly 34.x** | 11 | 17 | Last version supporting Java 11 |
| **WildFly 38.x+** | 17 | 21 | Java 11 support dropped |

### UBI Version Constraints

| Java Version | Minimum UBI | Recommended UBI | Notes |
|--------------|-------------|-----------------|-------|
| **OpenJDK 11** | UBI 9.0 | UBI 9.5+ | Deprecated (EOL Oct 2024, ELS to Oct 2027) |
| **OpenJDK 17** | UBI 9.0 | UBI 9.5+ | Stable LTS |
| **OpenJDK 21** | UBI 9.2 | UBI 9.5+ | Latest LTS (Recommended) |
| **OpenJDK 23** | Uses Java 21 base | UBI 9.5+ | No native Red Hat OpenJDK 23 image |

---

## Automation Opportunities

### Dependabot Configuration (GitHub)

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "maven"
    directory: "/metrics-sample-undertow"
    schedule:
      interval: "monthly"
    
  - package-ecosystem: "maven"
    directory: "/metrics-sample-springboot"
    schedule:
      interval: "monthly"
```

### Container Image Scanning (CI/CD)

Add to `.github/workflows/build.yml`:
```yaml
- name: Scan container image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    severity: 'CRITICAL,HIGH'
```

### Automated Testing

Add to CI pipeline:
```yaml
- name: Run validation scripts
  run: |
    ./scripts/quick-validate-builds.sh
    ./scripts/validate-buildconfigs.sh
```

---

## Related Documentation

- **[VERSIONS.md](VERSIONS.md)**: Current version matrix (single source of truth)
- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Build and deployment procedures with ARG overrides
- **[TESTING.md](TESTING.md)**: Validation scripts and troubleshooting
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)**: Technical architecture and design decisions
- **[CONTRIBUTING.md](CONTRIBUTING.md)**: Contribution guidelines

---

**Questions or Issues?**  
Open an issue on GitHub with the `version-management` label.
