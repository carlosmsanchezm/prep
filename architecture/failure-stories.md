# Failure Stories — Practice Telling These Aloud

## Instructions
Practice each story in 2-3 minutes. Hit: what happened, what YOU did, what you learned.
These show self-awareness and growth — interviewers love them.

---

## Story 14: Kapitan Profile Isolation Split (VivSoft)

### The Setup (30 seconds)
"During the JCRS-E migration, I designed a Kapitan profile isolation split — separating configuration profiles so each program's environment could be independently compiled and deployed."

### What Went Wrong (30 seconds)
"The approach looked correct in development, but when I pushed it for review, it had fundamental issues: ConfigMap naming conflicts between profiles, output class ownership mismatches, and cross-repo dependency issues. The root cause was that I designed the split based on how profiles should logically separate, without validating that Kapitan's recursive class inheritance would produce correct output for every combination."

### What I Did (60 seconds)
"I owned it immediately — pulled back the merge request and messaged the team and the government product owner within minutes. Clear status: approach has fundamental issues, I'm redesigning, no environments affected because nothing was merged. After that, I made two process changes. First, I mandated design documents for any architectural change — write the design, get review, prove assumptions with a focused POC before full implementation. Second, I added a configuration diff preview job to the pipeline — it compiles the Kapitan output and shows the full diff before deployment runs."

### The Lesson (30 seconds)
"Configuration inheritance systems have a much larger blast radius than they appear. You have to validate at the compiled-output level, not just the input level. The design document practice became standard for the team."

---

## Story 19: Keeping CaC and IaC Coupled (VivSoft)

### The Setup (30 seconds)
"My biggest misjudgment at VivSoft was keeping configuration-as-code and infrastructure-as-code in the same repository for the first several months of the JCRS-E migration. I made that call deliberately — I thought single-repo simplicity would speed us up."

### What Went Wrong (30 seconds)
"I didn't account for the classification boundary requirement. When configs touch SIPRNET, they get classified. If IaC and CaC share a repo, the entire repo becomes classified — you can't use it on the unclassified side without a review process. During one deployment cycle, a staging-specific RDS endpoint made it into the production bundle because the compile step pulled from the shared repo."

### What I Did (30 seconds)
"I separated the repos within two weeks — configuration into its own repository with Kapitan class inheritance, infrastructure staying in the original. The compile step now runs in isolation, nothing crosses boundaries unintentionally."

### The Lesson (30 seconds)
"I prioritized convenience over a national security constraint. When you know the operating constraints — especially classification boundaries — design for them from day one. Do not optimize for developer convenience and plan to fix it later. Later always costs more than now."

### If They Push: "What did you learn about your own decision-making?"
"I have a bias toward simplicity that can blind me to operational constraints I already know about. Now, before any architecture decision, I ask: am I choosing this because it's right for the operating model, or because it's easier right now?"

---

## How to Use These

**"Tell me about a failure"** → Story 14 (Kapitan)
**"Tell me about a misjudgment"** → Story 19 (CaC/IaC coupling)
**"What would you do differently?"** → Either one, depending on context
**"Tell me about a time something went wrong"** → Story 14

**Key pattern for all failure stories:**
1. State what happened — don't minimize
2. Show ownership — "I owned it immediately"
3. Show action — what you changed to prevent recurrence
4. Show learning — concrete, applied later
5. Never blame others
