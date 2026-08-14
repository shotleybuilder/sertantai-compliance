Here are 18 pre-made Views for SertantAI's Legal Glossary, designed to meet the practical needs of UK compliance professionals.

---

### **Core Browsing & Discovery Views**

1.  **View Name:** All Legal Definitions
    *   **Business Question:** I need a complete, searchable list of every definition in the glossary to quickly find any term.
    *   **Configuration:**
        *   **Filters:** None
        *   **Sorts:** `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** All users (default starting point, general lookup)

2.  **View Name:** Definitions Grouped by Law
    *   **Business Question:** I need to see all definitions organized by their source law, useful for understanding the scope of specific legislation.
    *   **Configuration:**
        *   **Filters:** None
        *   **Sorts:** `law_name` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Auditor, Trainer (for legal deep-dives or policy alignment)

---

### **Comparative & Applicability Views**

3.  **View Name:** Common Compliance Terms Comparison
    *   **Business Question:** How do fundamental terms like "employer" or "workplace" vary in definition across different laws? This helps establish applicability and identify nuances.
    *   **Configuration:**
        *   **Filters:** `term` IN ("employer", "employee", "workplace", "hazardous substance", "duty holder", "competent person")
        *   **Sorts:** `term` (A-Z), then `law_name` (A-Z)
        *   **Grouping:** `term`
    *   **Target User Persona:** Compliance Manager, Safety Manager, Environment Manager (for policy drafting, risk assessment, training)

4.  **View Name:** Environmental Compliance Focus
    *   **Business Question:** What are the key legal definitions relevant to environmental management across various UK laws?
    *   **Configuration:**
        *   **Filters:** `term` IN ("waste", "pollution", "hazardous waste", "emission", "environmental permit", "discharge", "producer responsibility")
        *   **Sorts:** `term` (A-Z), then `law_name` (A-Z)
        *   **Grouping:** `term`
    *   **Target User Persona:** Environment Manager, Compliance Manager (focused on environmental aspects)

5.  **View Name:** Health & Safety Compliance Focus
    *   **Business Question:** What are the core legal definitions relevant to health and safety management, crucial for risk assessments and policy development?
    *   **Configuration:**
        *   **Filters:** `term` IN ("hazard", "risk", "workplace", "employee", "employer", "duty holder", "competent person", "personal protective equipment", "accident", "incident", "first aid")
        *   **Sorts:** `term` (A-Z), then `law_name` (A-Z)
        *   **Grouping:** `term`
    *   **Target User Persona:** Safety Manager, Compliance Manager (focused on H&S aspects)

---

### **Change Management & Risk Views**

6.  **View Name:** Recently Updated Definitions
    *   **Business Question:** Which legal definitions have been updated recently, requiring my attention for potential policy or procedure changes?
    *   **Configuration:**
        *   **Filters:** `updated_at` (is within the last 30 days)
        *   **Sorts:** `updated_at` (Newest first)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager, Risk Manager, Legal Counsel (for proactive change management)

7.  **View Name:** Provision-Specific Definitions (High Granularity)
    *   **Business Question:** I need to identify definitions that are highly specific to a particular provision of a law, indicating very nuanced or context-dependent applications. These can be easily missed.
    *   **Configuration:**
        *   **Filters:** `scope` IS "provision"
        *   **Sorts:** `law_name` (A-Z), then `section_id` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Legal Counsel (for detailed risk assessment and interpretation)

8.  **View Name:** Definitions Referencing Other Laws
    *   **Business Question:** Which definitions rely on definitions found in other laws? This helps trace dependencies and ensure a complete understanding of a term's meaning.
    *   **Configuration:**
        *   **Filters:** `references_other_law` IS TRUE
        *   **Sorts:** `law_name` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Auditor, Legal Counsel (for understanding complex legal interconnections)

9.  **View Name:** Top-Level Definitions (No Cross-Refs)
    *   **Business Question:** I want to see definitions that *do not* reference other laws, as these are often foundational or self-contained, providing a good starting point for understanding.
    *   **Configuration:**
        *   **Filters:** `references_other_law` IS FALSE
        *   **Sorts:** `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager, Trainer (for understanding root definitions and building knowledge)

---

### **Audit & Training Views**

10. **View Name:** Definitions from Health & Safety at Work Act 1974
    *   **Business Question:** I need to review all definitions originating from the foundational Health and Safety at Work etc. Act 1974 for audit preparation or staff training.
    *   **Configuration:**
        *   **Filters:** `law_name` CONTAINS "Health and Safety at Work etc. Act 1974" (or specific ID like `UK_A_1974_37`)
        *   **Sorts:** `section_id` (A-Z), then `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** Safety Manager, Compliance Manager, Auditor, Trainer (for a universally relevant UK law)

11. **View Name:** Definitions for New Staff Training
    *   **Business Question:** What are the most fundamental legal terms that new compliance or operational staff should understand as part of their induction?
    *   **Configuration:**
        *   **Filters:** `term` IN ("employer", "employee", "workplace", "duty holder", "hazard", "risk", "competent person", "legal compliance", "due diligence")
        *   **Sorts:** `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager, HR Manager, Training Manager

---

### **Welsh Language Compliance Views**

12. **View Name:** Definitions with Welsh Translations
    *   **Business Question:** Which terms have official Welsh translations available, essential for bilingual compliance documents and communications?
    *   **Configuration:**
        *   **Filters:** `term_welsh` IS NOT NULL
        *   **Sorts:** `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager (especially in Wales), HR Manager, Communications Manager

13. **View Name:** Definitions Lacking Welsh Translations
    *   **Business Question:** Which terms *do not* yet have Welsh translations, highlighting potential gaps in our bilingual compliance and content strategy?
    *   **Configuration:**
        *   **Filters:** `term_welsh` IS NULL
        *   **Sorts:** `term` (A-Z)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager (especially in Wales), Product Team (for data improvement), Welsh Language Officer

---

### **Advanced & Specific Use Case Views**

14. **View Name:** Definitions from the Last Quarter
    *   **Business Question:** I need to review all definitions that were either newly inserted or updated within the last three months for a quarterly compliance review.
    *   **Configuration:**
        *   **Filters:** `inserted_at` (is within the last 90 days) OR `updated_at` (is within the last 90 days)
        *   **Sorts:** `updated_at` (Newest first)
        *   **Grouping:** None
    *   **Target User Persona:** Compliance Manager, Risk Manager (for regular reporting and review cycles)

15. **View Name:** Definitions Specific to a Law Part
    *   **Business Question:** I need to identify definitions that are specific to a particular 'part' of a law, which may have implications for how a section is interpreted.
    *   **Configuration:**
        *   **Filters:** `scope` IS "part"
        *   **Sorts:** `law_name` (A-Z), then `section_id` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Legal Counsel (for detailed legal interpretation)

16. **View Name:** Definitions by Source Type
    *   **Business Question:** I need to understand the origin or extraction method of definitions, useful for data quality checks or auditing the glossary itself.
    *   **Configuration:**
        *   **Filters:** None
        *   **Sorts:** `source` (A-Z), then `term` (A-Z)
        *   **Grouping:** `source`
    *   **Target User Persona:** Product Team, Data Quality Manager, Compliance Manager (for data governance)

17. **View Name:** Definitions with Specific Section IDs
    *   **Business Question:** I'm looking for definitions that are tied to specific, numbered sections or regulations within laws.
    *   **Configuration:**
        *   **Filters:** `section_id` IS NOT NULL (implies a specific section reference)
        *   **Sorts:** `law_name` (A-Z), then `section_id` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Legal Researcher (for precise legal referencing)

18. **View Name:** Definitions with Short Section IDs (e.g., "Reg 1", "Art 2")
    *   **Business Question:** I want to quickly find definitions that are likely from the very beginning of a law or part, often containing foundational or introductory terms.
    *   **Configuration:**
        *   **Filters:** `section_id` CONTAINS "1" OR `section_id` CONTAINS "2" OR `section_id` CONTAINS "3" (can be refined to regex for "regulation-1", "article-2" etc.)
        *   **Sorts:** `law_name` (A-Z), then `section_id` (A-Z), then `term` (A-Z)
        *   **Grouping:** `law_name`
    *   **Target User Persona:** Compliance Manager, Legal Researcher (for quickly finding introductory terms in legislation)
