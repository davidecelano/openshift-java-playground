# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation consolidation (Phases 1-6)
- `README.md` as project landing page with architecture diagram and samples matrix
- `TESTING.md` as single source of truth for all validation and troubleshooting
- `VERSION_MANAGEMENT.md` with complete update procedures and testing checklist
- `scripts/validate-openshift-deployment.sh` for end-to-end OpenShift workflow testing
- Navigation headers across all documentation files (10 files)
- "About This Sample" sections in all 4 sample READMEs explaining runtime selection rationale
- "Key Configuration" tables in sample READMEs documenting all tuning parameters
- "Comparing with Other Runtimes" tables for quick reference
- BuildConfig documentation section in DEPLOYMENT.md (~120 lines)
- Design decisions documentation in IMPLEMENTATION.md with rationales and alternatives

### Changed
- IMPLEMENTATION.md transformed from project completion report to technical architecture guide (+75% depth)
- QUICKSTART.md trimmed from 329 to 140 lines (58% reduction) removing duplicates
- DEPLOYMENT.md restructured with BuildConfig section, simplified troubleshooting
- Sample READMEs enhanced from 180 to 407 total lines (+126% growth)
- Documentation duplication reduced from 35% to <10% (71% reduction)

### Removed
- Duplicate troubleshooting content from QUICKSTART.md and DEPLOYMENT.md (consolidated to TESTING.md)
- Duplicate version override examples (consolidated to VERSIONS.md)
- Inline build script examples (replaced with references to ./scripts/)

## [2.0.0] - 2025-11-13

### Added
- UBI 9 migration complete for all samples (Java 11, 17, 21, 23)
- Comprehensive validation suite with 4 scripts (100% test coverage)
- `scripts/quick-validate-builds.sh` - Fast build-only validation (15 configs)
- `scripts/validate-buildconfigs.sh` - BuildConfig YAML + ARG override tests
- `scripts/validate-runtime.sh` - Runtime container + endpoint health tests
- `scripts/validate-all-builds.sh` - Comprehensive validation suite
- Phase 7 validation report documenting 100% success rate (38/38 tests)

### Changed
- **BREAKING**: All base images migrated from UBI 8 to UBI 9
- Tomcat upgraded from 10.1.15 to 10.1.49
- WildFly upgraded: 27.0.1.Final → 34.0.1.Final (Java 11), 31.0.1.Final → 38.0.0.Final (Java 17/21/23)
- Spring Boot upgraded to 3.4.0
- Package manager changed from `yum` to `microdnf` in Tomcat samples (UBI 9 requirement)
- WildFly Micrometer configuration simplified (built-in support in 34+/38+)

### Removed
- UBI 8 base images (fully replaced by UBI 9)
- Legacy Micrometer CLI configuration for WildFly (built-in support now)

## [1.0.0] - 2025-10-15

### Added
- Initial repository structure with 4 runtime samples
- Undertow sample with OpenJDK 11, 17, 21, 23
- Spring Boot sample with OpenJDK 17, 21, 23
- Tomcat sample with OpenJDK 11, 17, 21, 23
- WildFly sample with OpenJDK 11, 17, 21, 23
- Prometheus metrics integration for all samples
- OpenShift BuildConfig resources for cluster-native builds
- Kubernetes deployment manifests with resource limits
- ServiceMonitor resources for Prometheus scraping
- Dynamic version management via Dockerfile ARG directives
- Helper scripts: `build-all.sh`, `push-all.sh`, `deploy-all.sh`, `cleanup.sh`
- GitHub Actions CI/CD workflow for automated builds
- Security hardening (non-root, restricted SCC compliance)
- Container-aware JVM tuning flags (MaxRAMPercentage, InitialRAMPercentage)
- Initial documentation: README, DEPLOYMENT, CONTRIBUTING, VERSIONS

### Technical Details
- Base images: UBI 8 for Java 11/17, initial UBI 9 for Java 21/23
- Maven-based builds with multi-stage Dockerfiles
- Micrometer + Prometheus for metrics
- Security contexts: runAsNonRoot, no privilege escalation, capability drop

---

## Version History Summary

| Version | Release Date | Major Changes |
|---------|--------------|---------------|
| **2.0.0** | 2025-11-13 | UBI 9 migration, Tomcat 10.1.49, WildFly 34/38, comprehensive validation |
| **1.0.0** | 2025-10-15 | Initial release with 4 runtimes, 15 configurations, OpenShift BuildConfigs |

---

## Upgrade Guide

### Upgrading from 1.0.0 to 2.0.0

**Breaking Changes:**
1. All base images now use UBI 9 (UBI 8 no longer supported)
2. Tomcat version jumped from 10.1.15 to 10.1.49
3. WildFly versions changed significantly (34.x/38.x)

**Migration Steps:**

1. **Rebuild all images** (base images changed):
   ```bash
   ./scripts/build-all.sh
   ```

2. **Update deployments** (no manifest changes needed, but rebuilds required):
   ```bash
   ./scripts/deploy-all.sh
   ```

3. **Verify metrics endpoints** (no breaking changes in metrics format):
   ```bash
   ./scripts/validate-runtime.sh
   ```

4. **Review WildFly metrics** (namespace changed from custom to `base_`):
   - Prometheus queries may need adjustment
   - Metrics endpoint still on port 9990

**No Action Required:**
- Dockerfile ARG structure unchanged (override methods still work)
- Kubernetes manifest structure unchanged
- ServiceMonitor configurations unchanged
- Environment variable patterns unchanged

---

## Contributing to Changelog

When contributing, please update this file following these guidelines:

1. **Add entries under `[Unreleased]`** for new changes
2. **Use categories**: Added, Changed, Deprecated, Removed, Fixed, Security
3. **Be specific**: Include file names, line counts, and impact
4. **Link issues**: Reference GitHub issues where applicable
5. **Update version history**: Maintain the summary table

For more details, see [CONTRIBUTING.md](CONTRIBUTING.md).
