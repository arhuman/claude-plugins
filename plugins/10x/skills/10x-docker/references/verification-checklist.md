# Docker Configuration Verification Checklist

Before completing any Docker configuration task, verify:

- [ ] Non-root user (1001) with K8S permissions (`chmod g=u` or explicit group 0)
- [ ] Multi-stage builds for Go applications
- [ ] Healthchecks for all dependencies (databases, external services)
- [ ] Proper `depends_on` with `condition: service_healthy`
- [ ] Environment variables documented in `env.sample`
- [ ] Volume mounts configured correctly with correct paths
- [ ] Port mappings non-conflicting (use non-standard external ports: 23306, 25432)
- [ ] Timezone set (`TZ=Europe/Zurich`)
- [ ] `.dockerignore` file present and trimmed
- [ ] Build optimization (dependency layers before source layers)
- [ ] No secrets in committed files (use `.env`, not `env.sample`)
- [ ] Comments for non-obvious configuration choices
