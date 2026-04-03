# Draw Practice Guide

## Instructions

Each day during the Architecture block, pick ONE system and do this:

1. **Close all references.** No screens, no notes.
2. **Get a blank sheet of paper** (or use a whiteboard if you have one).
3. **Set a timer for 10 minutes.**
4. **Draw the system architecture** — boxes, arrows, labels.
5. **Narrate out loud as you draw** — pretend the interviewer is sitting next to you.
6. **After the timer:** open the reference file and compare. What did you miss?
7. **Practice the follow-up questions** from the reference file (5 min each, aloud).

## Daily Rotation

| Day | System to Draw | Exercise File | Answer Key | Coaching |
|-----|---------------|---------------|------------|----------|
| 1 | VivSoft JCRS-E (6 layers + repos) | vivsoft-platform.md | vivsoft-answers.md §2+5 | coaching-guide → System 1 |
| 2 | **IBM Helm Migration** (before → plan → after) | ibm-helm-migration.md | ibm-migration-answers.md | ibm-helm-migration.md coaching section |
| 3 | **Nightwatch RKE2** (cluster + GPU + auth + GitOps) | nightwatch-rke2.md | ntconcepts-answers.md (chart 3) | nightwatch-rke2.md coaching section |
| 4 | Air-gap delivery flow (connected → diode → deploy) | vivsoft-airgap-delivery.md | vivsoft-answers.md §8 | coaching-guide → System 2 |
| 5 | Bird-Dog network (TGW + NFW + spokes) + packet trace | ntconcepts-bird-dog.md | ntconcepts-answers.md (chart 1) | coaching-guide → System 4 |
| 6 | **Anduril K8s Pitch** (combine IBM + Nightwatch → phased plan) | anduril-k8s-migration-pitch.md | — | anduril-k8s-migration-pitch.md coaching |
| 7 | Pick your WEAKEST system + 3 tradeoff questions cold | tradeoff-questions.md | — | coaching-guide → General Techniques |

**Priority for Anduril onsite:** Days 2, 3, and 6 are the most critical — IBM migration, Nightwatch RKE2, and the combined pitch. These are what differentiate you from other candidates.

### How to Check Your Work

After drawing from memory:
1. Open the **answer key** file — compare your drawing against the real mermaid diagrams with actual component names, CIDRs, and connections
2. Open the **coaching guide** (`deep-dive-coaching-guide.md`) — review the narration script and emphasis points for that system
3. Practice the follow-up questions from the exercise file aloud

## Tips for Drawing in an Interview

- **Start with the big picture** — draw 3-4 boxes showing the major components first
- **Label everything** — don't just draw boxes, write what's inside
- **Show data flow** — arrows with labels like "gRPC", "HTTPS", "bundle transfer"
- **Call out boundaries** — "this is the connected side, this is the air-gapped side"
- **Name specific tools** — "Zarf for bundling, Harbor for registry, ArgoCD for GitOps"
- **Explain WHY as you draw** — "I put the firewall here because all egress needs inspection"
- **Don't try to draw everything** — focus on the parts relevant to the question
- **If you forget something:** say "and there's also X, but let me focus on the part that matters for this question"

## What Interviewers Look For

1. **Can you explain YOUR system clearly?** (not abstract knowledge — YOUR actual work)
2. **Do you understand WHY each component is there?** (not just WHAT)
3. **Can you go 3-4 levels deep?** (surface → component → config detail → tradeoff)
4. **Do you know the tradeoffs?** (what you chose, what you rejected, why)
5. **Can you identify what you'd do differently?** (shows growth, not perfection)
