# Architecture Practice: NTConcepts Cloud Governance Board

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the governance structure: who was involved, what data fed it, what outputs it produced
2. Draw the CUR ingestion pipeline
3. Explain how you influenced VPs without formal authority
4. Narrate out loud — 8 minutes

---

## What You Should Be Able to Draw

### Governance Structure

```
┌────────────────────────────────────────────────────┐
│              Cloud Governance Board                 │
│                                                    │
│  Chair: Carlos (Lead DevSecOps)                    │
│  Members: VP Finance, VP Engineering, Head IT/Sec  │
│                                                    │
│  Cadence: Monthly                                  │
│  Scope: 30 AWS accounts + 30 GCP projects          │
└───────────────┬────────────────────────────────────┘
                │
        ┌───────┴───────┐
        │               │
   ┌────▼────┐    ┌─────▼──────┐
   │  Cost   │    │  Security  │
   │  Track  │    │  Track     │
   └────┬────┘    └─────┬──────┘
        │               │
   Spend trends    Finding closure
   Root cause      CVE status
   Recommendations Compliance gaps
   Savings Plans   Remediation plans
```

### CUR Ingestion Pipeline (Data Engineering!)

```
AWS Cost & Usage Reports (CUR)
    ↓
S3 bucket (raw CUR files — CSV/Parquet)
    ↓
Python ETL script (parse, normalize, aggregate)
    ↓
Queryable format (dashboards, reports)
    ↓
Governance Board presentations
    ↓
Action items: rightsizing, Savings Plans, account cleanup
```

### FinOps Automation Suite

| Component | What It Does |
|-----------|-------------|
| CUR ingestion pipeline | First consolidated view of spend across all 60 accounts |
| Savings Plan recommender | Analyze usage patterns → recommend commitment levels |
| RI rightsizing | Compare reserved vs. actual usage → downsize/upgrade |
| GPU/CPU idle-shutdown | Python jobs monitor utilization → stop idle instances |
| Dashboards | Presented at Board meetings — executive visibility |

### Results
- ~30% reduction in cloud compute spend across 60 accounts
- 100% closure of critical/high security findings
- Board continued meeting after Carlos left — self-sustaining process

---

## Follow-Up Questions (Answer Aloud)

1. **"How did you influence VPs without formal authority?"**
   - Led with data — built dashboards showing the problem clearly
   - Proposed specific actions with projected savings (not just "we're spending too much")
   - When you bring a VP a problem AND a solution with numbers, they listen
   - Monthly cadence built trust over time

2. **"What was the biggest resistance?"**
   - Engineering teams resisting tagging enforcement
   - Solved by implementing mandatory tags in Terraform modules
   - You literally cannot provision resources without tags
   - Shifted from voluntary to enforced-by-design

3. **"How does this relate to Anduril?"**
   - Same pattern: cross-functional collaboration, data-driven decisions
   - Governance + automation beats manual oversight
   - I built a mechanism, not a one-time cleanup
