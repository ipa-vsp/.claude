---
name: cv-toolkit
description: CV/resume review toolkit with six modes - CV X-Ray, Job Description Decoder, ATS Bypass Optimizer, Achievement Transformer, Recruiter 6-Second Test, Final CV Audit. Use when the user wants to analyze, tailor, or improve a CV/resume against a job description.
---

# CV Toolkit

Never invent facts about the candidate; any suggested numbers must be labelled placeholders to verify. Don't upload CVs to unapproved services; no personal data in notes.

## Interactive protocol (mandatory)

Run as a step-by-step interview. **Ask exactly ONE question per message, then stop and wait for the answer.** Never batch questions, never skip ahead, never assume an answer. Use the AskUserQuestion tool for multiple-choice questions when available; otherwise plain text.

**Step 1 - Mode.** Ask which mode to run:
`1 X-Ray` · `2 JD Decoder` · `3 ATS Optimizer` · `4 Achievement Transformer` · `5 Recruiter 6-sec Test` · `6 Final Audit` · `7 Full workflow (all, in order)`.

**Step 2 - Inputs, one at a time.** Ask only for the inputs the chosen mode needs, in this order, one per message:
1. Target industry / role (modes 1, 7).
2. Job description - "Paste the full JD" (modes 2, 3, 5, 7; optional for 6 - ask "Do you have a JD to audit against? (yes/no)").
3. CV - "Paste your CV as plain text" (modes 1, 3, 5, 6, 7).
4. Bullet points - for mode 4, ask whether to use the bullets from the CV already pasted or paste new ones.
5. Optional context, single question: "Any numbers, team sizes, budgets or results I should know? (or 'skip')".

If an answer is unclear or incomplete, ask one follow-up question before moving on. Briefly confirm what was received ("Got your JD - 42 lines") before the next question.

**Step 3 - Run the mode** and output the result.

**Step 4 - Checkpoint.** After every mode, ask one question: "Continue to the next step, revise this one, or stop?" In full workflow (7), go through modes in order 2 → 1 → 4 → 3 → 5 → 6, reusing inputs already given, and checkpoint between each. When a mode produces rewrites (3, 4), ask "Apply these changes to the working CV? (yes / no / pick which)" and carry the accepted version into the next step.

For mode 4 placeholders: ask the user to confirm or correct each `[verify: ...]` value, one bullet at a time, before finalising.

## 1. CV X-Ray Analyzer
Inputs: industry, CV.
Act as a senior HR professional with 15 years of recruiting experience in the industry. Screen the CV like a real candidate. Be brutal, not nice. Report:
1. Sections that make you skip immediately.
2. Achievements that are too weak and need strengthening.
3. The one thing that would get the candidate rejected in the first 10 seconds.

## 2. Job Description Decoder
Inputs: JD.
Break the JD down section by section and give:
1. Hidden skills not written but definitely expected.
2. Red flags if a candidate is missing them.
3. The 3 must-have keywords that must appear in the CV.
4. What the hiring manager actually cares about that the JD never says directly.

## 3. ATS Bypass Optimizer
Inputs: CV, JD.
Act as an ATS specialist.
1. Identify every gap between CV and JD.
2. Rewrite the Experience and Skills sections using the JD's exact keywords naturally, not stuffed. Target ATS score 90+ (state it is an estimate).
3. Show before and after for every change.

## 4. Achievement Transformer
Inputs: CV bullet points.
Assume each bullet describes a duty, not a result. Rewrite each as:
**Strong action verb + what I did + measurable result + business impact.**
If no numbers are given, suggest realistic placeholders marked `[verify: ...]`. Make a recruiter stop scrolling.

## 5. Recruiter Mind Reader
Inputs: JD, CV.
You are a recruiter with 200 CVs for this role and 6 seconds per CV. Tell:
1. Shortlist or skip within 6 seconds, and why.
2. The first thing that catches your eye.
3. The first thing that kills the candidate's chances.
4. What would make you call immediately.

## 6. Final CV Audit
Inputs: final CV (JD optional).
Audit every section: ATS compatibility, keyword strength, achievement quality, formatting clarity, summary impact, skills relevance, length appropriateness. Score each out of 10 (table). For each weakness give the precise fix. Goal: 90+ overall before sending; list what remains to get there.

## Full workflow order
2 (decode JD) → 1 (X-Ray) → 4 (transform bullets) → 3 (ATS optimize) → 5 (6-second test) → 6 (final audit). Checkpoint question between each step.
