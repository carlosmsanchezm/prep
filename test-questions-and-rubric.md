# Anduril Interview — Test Questions + Evaluation Rubric

## How to Use

1. Feed each question to Grok one at a time
2. Record or paste the transcript
3. Score each answer against the rubric
4. Flag any failures for prompt tuning

---

## INTERVIEW 1: Infrastructure with Andrew Lunceford (2:00-3:00 PM)

### Category A: Rapid-Fire Concept Questions (expect 20-40 word answers)

**A1.** "What is infrastructure as code?"

**A2.** "What's the difference between Ansible and Terraform?"

**A3.** "What is idempotency and why does it matter?"

**A4.** "Explain the difference between a security group and a NACL."

**A5.** "What is a Transit Gateway?"

**A6.** "What are VPC endpoints and why would you use them?"

**A7.** "What's the difference between a container and a virtual machine?"

**A8.** "What is configuration drift?"

**A9.** "Explain mTLS in one or two sentences."

**A10.** "What is the difference between symmetric and asymmetric encryption?"

### Category B: Infrastructure Experience (expect 100-200 word answers)

**B1.** "Walk me through your experience with air-gapped environments."

**B2.** "Tell me about your Ansible experience — are you writing your own roles or mostly using community ones?"

**B3.** "Describe a network architecture you designed."

**B4.** "How do you handle secrets management in your infrastructure?"

**B5.** "Walk me through how you deploy software to a disconnected network."

**B6.** "What's your experience with Kubernetes? Have you stood up clusters from scratch?"

**B7.** "How do you approach hardening a Linux host for a DoD environment?"

**B8.** "Tell me about your CI/CD pipeline architecture."

### Category C: Architecture Deep Dive (expect 150-200 word answers, possibly drawing)

**C1.** "Walk me through the most complex infrastructure you've built."

**C2.** "How would you design a system to get software updates to an air-gapped network through a diode?"

**C3.** "Explain your approach to multi-account strategy in AWS GovCloud."

**C4.** "How do you handle container image supply chain security?"

**C5.** "If you were starting a Kubernetes rollout on an on-prem air-gapped network from scratch, how would you approach it?"

### Category D: Tradeoff / Judgment Questions (expect 100-150 word answers)

**D1.** "Why would you choose Ansible over Terraform for an air-gapped environment?"

**D2.** "When would you use ArgoCD vs FluxCD?"

**D3.** "What's the tradeoff between a monorepo and multi-repo for platform code?"

**D4.** "You inherit a system with significant technical debt but it's working. Do you rewrite or iterate?"

**D5.** "How do you balance day-to-day firefighting with longer-term infrastructure improvements?"

---

## INTERVIEW 2: Behavioral with Felipe Tejero (3:00-4:00 PM)

### Category E: Core Behavioral (expect CARL stories, 150-200 words)

**E1.** "Tell me about yourself."

**E2.** "Tell me about a time you took ownership of something that wasn't your responsibility."

**E3.** "Describe a situation where you had to influence others without formal authority."

**E4.** "Tell me about your biggest technical failure. What happened and what did you learn?"

**E5.** "Give me an example of when you disagreed with a technical decision. How did you handle it?"

**E6.** "Tell me about a time you had to make a decision with incomplete information."

**E7.** "Describe a time you improved a process or system that was already working."

**E8.** "Tell me about a time you mentored someone or helped develop a teammate."

### Category F: Leadership / Collaboration (expect 100-200 word answers)

**F1.** "How do you approach joining a team that's already moving fast on a critical program?"

**F2.** "How do you handle conflicting priorities from multiple stakeholders?"

**F3.** "What's your leadership style? How do you lead a small team?"

**F4.** "Tell me about working with engineers who have very different skill sets than you — embedded, electrical, mechanical."

**F5.** "How do you handle context-switching between multiple priorities?"

### Category G: Role Fit / Motivation (expect 100-150 word answers)

**G1.** "Why Anduril?"

**G2.** "Why are you leaving your current role?"

**G3.** "What excites you about working on air-gapped, on-prem infrastructure?"

**G4.** "Where do you see yourself in two to three years?"

**G5.** "What's your biggest weakness?"

### Category H: Follow-Up Probes (use AFTER a behavioral answer)

**H1.** "Why did you choose that approach over alternatives?"

**H2.** "What trade-offs did you accept?"

**H3.** "Did you get pushback? From whom?"

**H4.** "What would you do differently if you could go back?"

**H5.** "What was the business or mission impact?"

---

## EVALUATION RUBRIC

### Scoring Scale

| Score | Meaning |
|-------|---------|
| **5** | Perfect — right length, right depth, right format, no violations |
| **4** | Good — minor issues (slightly long, one small violation) |
| **3** | Acceptable — gets the point across but has noticeable issues |
| **2** | Needs tuning — wrong format, too long, fabrication, or missed the question type |
| **1** | Fail — major violation (fabricated, ended with a question, rambling, wrong persona) |

### Dimension 1: Length Compliance

| Question Type | Expected Length | Score 5 | Score 3 | Score 1 |
|--------------|----------------|---------|---------|---------|
| Rapid-fire concept (A) | 20-40 words | Under 50 words, direct | 50-100 words, correct but too long | Over 100 words, added a story |
| Experience (B) | 100-200 words | 100-200, specific, stops cleanly | Over 200 but relevant | Over 300, rambles |
| Deep dive (C) | 150-200 words | 150-200, layered, detailed | Over 250 but structured | Over 300, loses focus |
| Tradeoff (D) | 100-150 words | States both sides, picks one with reasoning | Correct but verbose | Doesn't name the tradeoff |
| Behavioral CARL (E) | 150-200 words | Full CARL, under 200 | CARL but over 250 | Missing context or result |
| Leadership (F) | 100-200 words | Framework + brief example | Over 200, multiple stories | Vague, no specifics |
| Role fit (G) | 100-150 words | Direct, genuine, specific to Anduril | Correct but generic | Could be said about any company |
| Follow-up probe (H) | 75-125 words | One new fact, no repetition | Slightly repeats initial answer | Restates the same story |

### Dimension 2: Format Compliance

| Rule | What to Check | Pass | Fail |
|------|--------------|------|------|
| First person | Uses "I designed," "I built" | "I" throughout | "We did," "The team realized" |
| No question at end | Answer ends on result/insight | Ends with content, stops | "What do you think?" / "Which side are you on?" |
| Spoken prose | Flowing sentences, connectors | "Then," "from there," "which meant" | Bullets, arrows, dashes, lists |
| No fabrication | Facts match KB | Real metrics, real tools, real stories | Invented numbers, fake incidents |
| No flair phrases | Professional tone | Measured, confident | "That's my jam," "no ego just results," "bottom line" |
| No file paths/commands | Conversational | "I wrote a configuration file" | "/etc/rancher/rke2/config.yaml" |
| Starts immediately | No preamble | First sentence = substance | "Great question, let me think about that..." |
| Concept questions clean | No story for knowledge checks | Textbook definition, done | "At VivSoft, I used encryption at rest for..." |
| Rapid-fire pace | Matches interviewer speed | 20-40 words, stops | 150 words for "What is a VPC?" |

### Dimension 3: Content Quality

| Criterion | Score 5 | Score 3 | Score 1 |
|-----------|---------|---------|---------|
| **Accuracy** | Technically correct, precise | Mostly correct, minor imprecision | Wrong or misleading |
| **Specificity** | Names tools, numbers, decisions | Somewhat specific | Vague platitudes |
| **Ownership** | "I decided," "I designed" | Mix of I and we | "The team did," passive voice |
| **Tradeoff awareness** | Names what was sacrificed | Mentions tradeoff vaguely | Fairy-tale ending |
| **Relevance to Anduril** | Bridges to air-gap/on-prem/IC naturally | Generic answer | Irrelevant tangent |
| **Stops cleanly** | Ends on result, silence | Slight trailing thought | Rambles, adds coaching, asks a question |

### Dimension 4: Question Type Routing

| Question Type | Correct Routing | Wrong Routing |
|---------------|----------------|---------------|
| "What is X?" | Direct definition, no story | CARL story about using X |
| "Tell me about a time..." | CARL story from KB | Philosophy answer with no example |
| "How do you approach..." | Framework/principle first, then brief example | Full CARL story without stating the approach |
| "Why Anduril?" | 3-reason framework, Anduril-specific | Generic answer about any company |
| "Do you have experience with X?" | YES/NO first, then 2-3 sentences | 200-word story before answering yes |
| Interviewer sharing context | "That tracks" / "Makes sense" + 1 sentence | Full 200-word response matching their monologue |
| Follow-up probe | ONE new layer of depth | Repeats the initial answer |

---

## QUICK SCORECARD

Use this during evaluation. Score each answer 1-5 across the 4 dimensions.

```
Question | Length | Format | Content | Routing | Notes
---------|--------|--------|---------|---------|------
A1       |        |        |         |         |
A2       |        |        |         |         |
...      |        |        |         |         |
```

### Red Flags (auto-fail any answer with these)

- Fabricated a metric or incident not in the KB
- Ended with a question back to the interviewer
- Used flair phrases ("bottom line," "no ego," "that's my jam")
- Spoke a file path, CLI command, or URL literally
- Answered a concept question with a full CARL story
- Said "we" without claiming individual contribution
- Over 300 words on any single answer
- Repeated the interviewer's question back before answering

### Green Flags (mark these as strong signals)

- Bridges to Anduril's air-gap/on-prem/IC context naturally
- Names a specific tradeoff and what was sacrificed
- Uses a metric from the KB accurately
- Stops cleanly after the result — no trailing question or coaching
- Matches rapid-fire pace when concepts come fast
- Follow-up adds genuine new depth without repeating
