# Contributing to OpenShift Java Playground

Thank you for contributing! This repository is a collaborative resource for testing Java container behavior on OpenShift.

## How to Contribute

### 1. Add New Sample Applications

Create a new runtime variant (e.g., Quarkus, Helidon):

```bash
# Create directory structure
mkdir -p metrics-sample-<runtime>/src/main/java/com/example/metrics
mkdir -p metrics-sample-<runtime>/k8s

# Follow existing patterns:
# - pom.xml with minimal dependencies
# - Expose /health and /metrics endpoints
# - Dockerfile.openjdk{11,17,21,23}
# - k8s/deployment-openjdk{11,17,21,23}.yaml
# - k8s/service.yaml, k8s/servicemonitor.yaml
# - README.md with build/deploy instructions
```

### 2. Add New Experiment Scenarios

Create a scenario directory following `example-scenario-heap-comparison/` structure:

```bash
mkdir -p <scenario-name>
cd <scenario-name>

# Required files:
# - README.md: Goal, setup, procedure, expected results
# - Deployment manifests or scripts
# - Results template (tables, queries)
```

**Scenario Naming Convention**: `<category>-<focus>` (e.g., `tuning-cgroups-v2`, `gc-comparison-g1-vs-zgc`)


### 3. Improve Documentation

- Update `.github/copilot-instructions.md` with new patterns discovered
- Add troubleshooting tips to `DEPLOYMENT.md`
- Expand runtime-specific tuning guidance in copilot instructions
- When adding or updating scripts (e.g., `deploy-all.sh`, `build-all.sh`), ensure their usage, prerequisites, and expected output are documented in `README.md`, `QUICKSTART.md`, and `DEPLOYMENT.md` as appropriate.
- When changing version management mechanisms (Dockerfile ARGs, BuildConfig buildArgs, environment variable overrides), update `README.md`, `QUICKSTART.md`, and `VERSIONS.md` with clear usage examples and cross-references.
### 5. Documentation Consistency

- Cross-reference related scripts and documentation sections for clarity and discoverability.
- Ensure all instructions are consistent and up to date with the latest repository state.

### 4. Enhance CI/CD

Modify `.github/workflows/build-metrics-samples.yml` to:
- Add new runtime builds
- Include validation steps
- Deploy to test cluster

## Contribution Guidelines

### Code Style

**Java**:
- Standard Oracle/OpenJDK formatting
- Minimal dependencies (prefer provided scope)
- Clear, self-documenting code

**Shell Scripts**:
- Use `set -e` for error handling
- Add explanatory comments
- Include usage examples in headers

**YAML**:
- 2-space indentation
- Explicit resource limits
- Labels for filtering (`app`, `version`, `scenario`)

### Commit Messages

Follow conventional commits:

```
feat: add Quarkus metrics sample with native image support
fix: correct Tomcat maxThreads environment variable handling
docs: expand cgroups v2 tuning guidance
chore: update GitHub Actions to use Podman 4.x
```

### Testing Before PR

1. **Build locally**: Test all Dockerfiles build successfully
2. **Validate YAML**: `oc apply --dry-run=client -f k8s/`
3. **Deploy to test cluster**: Verify pods start and metrics accessible
4. **Check linting**: Ensure shell scripts pass `shellcheck`

```bash
# Example validation
cd metrics-sample-<runtime>
podman build -f Dockerfile.openjdk17 -t test:local .
oc apply --dry-run=client -f k8s/
shellcheck ../scripts/*.sh
```

### Pull Request Process

1. **Fork the repository** and create a feature branch
2. **Make changes** following guidelines above
3. **Update README.md** if adding new samples or major features
4. **Test thoroughly** in a real or local OpenShift environment
5. **Submit PR** with clear description of changes and motivation

**PR Template**:
```markdown
## Description
Brief summary of changes

## Type of Change
- [ ] New sample application
- [ ] New experiment scenario
- [ ] Documentation improvement
- [ ] Bug fix
- [ ] CI/CD enhancement

## Testing
- Tested on: OpenShift 4.x / Kubernetes 1.x
- Java versions validated: 11, 17, 21, 23
- Deployment successful: Yes/No

## Screenshots / Results
(if applicable)

## Checklist
- [ ] README.md updated
- [ ] Scripts are executable
- [ ] YAML manifests validated
- [ ] Follows existing patterns
```

## Scope and Focus

### In Scope
- OpenJDK runtime behavior in containers
- Resource tuning experiments (heap, threads, CPU)
- Version compatibility studies
- Metrics and observability patterns
- Deployment automation

### Out of Scope
- Oracle commercial Java features
- Application-specific business logic
- Non-Java runtime comparisons (unless comparative study)
- Production-grade security hardening (demo purposes only)

## Questions or Ideas?

Open an issue for:
- Experiment ideas
- Documentation clarifications
- Feature requests
- Bug reports

Label appropriately:
- `enhancement`: New features or samples
- `documentation`: Docs improvements
- `bug`: Something isn't working
- `question`: Further information requested

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (typically Apache 2.0 or MIT - check repository).

## Code of Conduct

Be respectful, constructive, and collaborative. This is a learning and experimentation space for the community.

---

Thank you for helping improve Java container deployments on OpenShift!
