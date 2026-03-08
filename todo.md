- [?] Have tofu:destroy also destroy resources spawned by k3s calls to Hetzner CSI
- [ ] Gatus health checks
    - [x] `values.yaml.j2` moved to `templates/` directory
    - [x] Gatus service refactored to services layer
    - [ ] Replace hardcoded `supersecret` DB password in `defaults/main.yml` with 1Password reference
    - [ ] Add `GATUS_DB_PASSWORD` to `mise.toml` with 1Password path
    - [ ] Configure monitoring endpoints
- [ ] Forgejo
- [ ] Forgejo Actions
- [ ] CopyParty
- [ ] Step-CA
    - [ ] Deploy Step CA service/pod/etc
    - [ ] Configure cluster for Zero-Trust Internal Ingress to issue
        certificates for internal-only domains that never touch the public internet.
    - [ ] Configure CloudNativePG so Step CA is a ClusterIssuer for CNPG using
        short-lived, auto-rotating certificates.
    - [ ] Secure Service-to-Service Communication (mTLS) for M2M
    - [ ] Configure for Authentik "User/Device Identity" provisioning so as
        to allow Step CA to redirect to the Authentik login; once authenticated,
        a short-lived personal certificate is issued that can be used to
        access protected cluster resources or SSH into K3s nodes.
        
- [ ] Ntfy (ntfy.twobitrobit.com)
    - [x] Upgrade Authentik blueprints to 2026.2.1 schema
        - [x] Add verification_kp to Proxy Provider (#20628)
        - [x] Replace !KeyOf with !Find references
        - [x] Add RBAC role with group-based assignment
        - [x] Add custom ntfy_publisher scope mapping
    - [x] M2M JWT federation deferred to Step-CA (mTLS)
        - Authentik jwt_federation_providers unsupported for self-referential auth
        - See: https://github.com/goauthentik/authentik/discussions/11764
    - [ ] M2M functionality confirmed on fresh deployment (after Step-CA integration)
    - [ ] M2M confirmed to use service account (instead of global)

- [ ] Switch certs to prod
    - [x] ClusterIssuer defaults to production (`values.yaml` issuer: production)
    - [x] Production certs already issued (Let's Encrypt R12 intermediate verified)
    - [ ] Remove AUTHENTIK_INSECURE from `services/identity/.../values.yaml.j2:40`
