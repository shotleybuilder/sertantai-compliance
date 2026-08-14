**1. Recommendation: Option A — Service-scoped capabilities in JWT**

**Reasoning:**
Option A is the superior choice for SertantAI due to its inherent flexibility, granularity, and future-proofing. The problem statement explicitly notes that "future services may need finer granularity," which directly points to the strengths of a capability-based model.

1.  **Granularity:** Capabilities like `compliance:register:read` and `compliance:register:write` are precise and directly address the immediate need for read/write distinction. This model easily extends to much finer-grained permissions (e.g., `screening:view`, `screening:approve`, `legal:document:upload`) without forcing an awkward role hierarchy or role proliferation.
2.  **Service Autonomy:** Each service can define its own set of capabilities without coupling to Auth's central role definitions or impacting other services. This promotes loose coupling, a hallmark of good microservice architecture. When `sertantai-legal` needs new permissions, it defines its own capabilities, not new roles in Auth that might affect Hub or Compliance.
3.  **Scalability & Evolution:** As the platform grows and services evolve, new features requiring new permissions can introduce new capabilities without requiring changes to a fixed `service_roles` enum. This avoids the "role explosion" problem that Option B would likely encounter when granularity increases.
4.  **Direct Enforcement:** Services directly check for specific capabilities in the JWT, making the authorization logic transparent and efficient, aligning with the "self-contained JWT" constraint.

Option B, while seemingly simpler initially, would quickly become unwieldy. Creating `compliance:editor` and `compliance:viewer` roles is fine for now, but what if a user needs to *only* edit legal registers but *not* screening rules? Option B would force the creation of more and more specific roles (e.g., `compliance:register_editor`), leading to a complex and hard-to-manage role matrix.

**2. Risks or edge cases with Option A:**

*   **JWT Size Bloat:** If a user is assigned many capabilities across numerous services, the JWT could grow significantly. While generally not a critical issue with concise capability strings, it's a factor for network transfer and parsing performance. *Mitigation:* Keep capability strings short, consider grouping common capabilities, and ensure JWT expiry is short.
*   **Capability Sprawl & Management Complexity in Hub:** Without clear naming conventions and governance, the number of capabilities could become difficult to manage in Hub's UI. Hub will need a robust interface to display, assign, and revoke capabilities, potentially categorized by service or resource. *Mitigation:* Implement strict naming conventions (e.g., `service:resource:action`), provide search/filter in Hub.
*   **Security by Incomplete Implementation:** Services must diligently check for the correct capabilities at every authorization point. Forgetting to check a capability on a new endpoint or resource is a direct security vulnerability. *Mitigation:* Strong code review, automated security testing, and the use of a common authorization middleware or library within each service.

**3. Interaction with the existing org-wide role:**

The existing `role` (owner/admin/member/viewer) should act as a **baseline or default set of capabilities**, with the `capabilities` map providing user-specific overrides or augmentations.

*   **Implicit Capabilities:** `sertantai-auth` should define a default set of capabilities for each org-wide role. For example:
    *   `owner`/`admin`: Might implicitly grant *all* capabilities for all services (e.g., `*:*:*` or bypass capability checks entirely).
    *   `member`: Might implicitly grant `compliance:register:read`, `sertantai-hub:subscription:view`, etc.
    *   `viewer`: Might grant only `*:*:read` capabilities.
*   **Hierarchical Resolution:** When generating the JWT, `sertantai-auth` would combine the implicit capabilities derived from the `role` with any *explicitly assigned* capabilities for the user. Explicit assignments should generally take precedence, allowing administrators to grant more (or less) specific permissions than the default role. For instance, a `member` user explicitly granted `compliance:register:write` would receive that capability, even if their base `member` role only implies `read`. This allows for fine-tuning while retaining the simplicity of base roles.

**4. Flag anything we might be missing:**

*   **Centralized Capability Discovery:** Hub needs to know *what capabilities exist* for each service to present them in the UI. Services should expose their defined capabilities (e.g., via a well-known API endpoint, a shared configuration file, or a schema) that Hub can consume. Without this, Hub's UI would be brittle and require manual updates whenever a service's capabilities change.
*   **Initial Migration Strategy:** How will existing users be transitioned? Will all current `member` users automatically receive `compliance:register:write` until explicitly configured, or default to `read` only? A clear plan is needed to avoid disruption or unintended access.
*   **Auditing and Logging:** With more granular permissions, robust logging of authorization decisions and actions taken by users becomes even more critical for compliance and security.
*   **Policy Evolution:** Consider if, in the distant future, a more advanced policy-as-code system (e.g., OPA) might be needed if authorization rules become extremely complex and context-dependent. For now, simple capability strings are sufficient.
