<!--
Qompass AI Review
SPDX-License-Identifier: Apache-2.0
Copyright (c) 2026 Qompass AI

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at:
  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
################################################################# -->

# Peer Review

## Journal of Graduate Medical Education

### Manuscript Number: JGME-D-26-00785

### Title: *Evaluating the Effect of Detail in Prompting Large Language Models in Generating Dialogue for Simulation Exercises*

---

## Review Scores

| Category | Score |
|---|---|
| Reviewer Recommendation | **Reject** |
| Overall Manuscript Rating | **35/100** |
| Topic of interest to program directors or GME educators, researchers, or deans | 4 = Moderately Agree |
| Conclusions supported by data or evidence presented | 2 = Moderately Disagree |
| Methodological rigor appropriate to the study design | 2 = Moderately Disagree |
| Manuscript needs additional statistical review | Yes: reported effect sizes are inconsistent with the reported test statistics, and the Poisson model is fit to massively overdispersed data with no diagnostics reported |

---

## Confidential Comments to the Editor

This is a small, honestly reported study with a null result: detailed flow-chart prompting of four LLMs produced shorter but not higher-quality simulation dialogues than a standardized prompt, and no model met the authors' adopted quality threshold in the pediatric emergency context. I credit the authors for transparent reporting of the Gemini safety refusal and for flagging, themselves, that the 4.5 quality benchmark was never derived by its source study. Nevertheless, I recommend rejection in current form for three reasons. First, the study operates entirely within a prompt-only paradigm: zero-shot chat prompts, including a PDF flowchart uploaded through consumer chat interfaces, without engaging any contemporary method for making AI outputs more deterministic or reliable (structured/constrained output generation, retrieval-grounded generation, generate-and-verify pipelines, or open protocols standardizing context and tool exchange such as the Model Context Protocol). In 2026 this reads as a study of how models behaved in a chat window two generations ago, not of how educators would actually deploy them. Second, there are material methodological and statistical problems: the reported eta-squared values are mathematically inconsistent with the reported F statistics (e.g., F(1,3)=2.71 cannot yield eta-squared=.00 under any standard definition); the Poisson model is applied to word-count data with variance roughly 400 times the mean and no overdispersion diagnostics; the three raters were unblinded to prompt condition and drawn from the authors' own team, which also built the flowchart; and the repeated-measures ANOVA treats n=4 LLMs as participants. Third, the conclusions ("should guide clinicians and educators in choosing LLM and prompting strategies") overreach a null finding from 16 dialogues. A publishable successor would need blinded independent raters, output-level sampling with adequate n (as the authors themselves propose), fully specified model versions and generation settings reported per TRIPOD-LLM, and, most importantly, comparison conditions that reflect current practice for reliable generation rather than prompt wording alone.

---

## General Comments to Authors

Thank you for an honestly reported study. The research question is sensible: whether giving a model more detailed structural guidance improves the dialogue it generates for simulation, and I appreciate the transparent reporting of the Gemini safety refusal and the candid note that the 4.5 "high quality" benchmark was never derived by Haider et al. Null results on prompt engineering are worth publishing when the design supports them. The difficulty here is that the design does not support the conclusions drawn, and the study's framing is behind the current state of the field. The entire manipulation lives inside consumer chat windows: a standardized text prompt versus a PDF flowchart uploaded as an attachment. Prompt wording is no longer the only, or the most reliable, lever educators have for controlling model outputs, and the manuscript never engages the structured, grounded, or protocol-based approaches that now define reliable AI-generated educational content. Beyond this framing problem, the statistical reporting contains errors, the raters were unblinded members of the study team evaluating a condition their own team designed, and the sample (four LLMs as the unit of analysis) cannot support the ANOVA reported. I have detailed these points below with the aim of being useful whether you revise for another venue or redesign the study.

---

## Comment 1: manuscript p. 4 | lines 44–57; manuscript p. 5 | lines 4–7; manuscript p. 7 | lines 33–46

The study operates entirely within a prompt-only paradigm. The sole manipulation is prompt wording delivered through consumer chat interfaces (a standardized text prompt versus a PDF flowchart uploaded as an attachment) using free-tier accounts. By 2026, prompt phrasing is no longer the only, or the most reliable, way to make model outputs deterministic: structured and schema-constrained output generation, retrieval-grounded generation with citations, multi-step generate-and-verify pipelines, and open protocols that standardize how models receive context and invoke tools, such as the Model Context Protocol (https://modelcontextprotocol.io/), all exist precisely to reduce the nondeterminism this study wrestles with. The "detailed" condition is, moreover, one of the least deterministic ways to inject structure: each vendor's free tier parses PDF attachments differently, if at all, so the manipulation itself is not standardized across the four models, and the manuscript never discusses this fragility. The Discussion gestures toward iterative prompting as future work but never engages the constrained- or grounded-generation literature. Please situate the study within the current reliability landscape and justify why prompt-only approaches were tested rather than, or in addition to, structured-output or grounded-generation approaches, or at minimum acknowledge that uploading a flowchart to a chat window tests a historically narrow slice of how educators can steer models.

**Relevant literature:** The Model Context Protocol specification and documentation (https://modelcontextprotocol.io/) describe the open standard for deterministic context and tool exchange between AI applications and external systems.

## Comment 2: manuscript p. 4 | lines 48–57; manuscript p. 6 | lines 23–27; manuscript p. 7 | lines 9–18; manuscript p. 12/Table 1 | lines 13, 21

The flow-chart condition is underspecified, confounded, and its main finding is close to tautological. The flowchart was developed by the authors' own team and its content is not shown in the manuscript; the supplementary materials containing the prompts are referenced (manuscript p. 4, lines 50–53) but were not available to the reviewer, so the manipulation cannot be evaluated or reproduced. More fundamentally, the authors themselves note that in the flow-chart condition the models "did not need to solve the scenario, merely provide dialogue around the structure," which directly explains the shorter scripts: handing the model the scenario structure and then observing that its output is shorter is not an independent discovery about prompting. The manuscript frames shorter output as conciseness, but provides no evidence that shorter is better: mean Usability is identical across conditions (3.75 in both, Table 1), and shorter scripts could equally reflect omitted clinical content. Please either provide a completeness or content-coverage analysis showing what the shorter scripts retain versus lose, or drop the implication that reduced word count is a benefit.

## Comment 3: manuscript p. 5 | lines 35–44; manuscript p. 6 | lines 23–40

The statistical reporting contains errors that require correction and independent statistical review. First, the eta-squared values reported alongside the ANOVA are inconsistent with the reported F statistics under any standard definition. For example, the scenario effect F(1,3)=2.71 is reported with eta-squared=.00, but a nonzero F mathematically implies nonzero explained variance, so eta-squared=.00 is impossible. The other values are similarly discrepant: F(2,6)=4.15 does not yield .32, F(1,3)=8.42 does not yield .08, and F(1,3)=.655 does not yield .02 under partial eta-squared. Please recheck all four values and state explicitly whether partial, generalized, or classical eta-squared was computed. Second, the Poisson regression is fit to word-count data with M=1453 and SD=762 in the standard-prompt condition (a variance roughly 400 times the mean), yet no overdispersion diagnostics are reported and no alternative (e.g., negative binomial) is considered. Poisson assumes variance equals the mean, an assumption these data violate by orders of magnitude. Third, with 16 total dialogues, the b=-0.18, p<.001 estimate is presented without confidence intervals. These analyses need re-running with appropriate models and full reporting before any inference is drawn.

## Comment 4: manuscript p. 4 | lines 37–44 and 55–57; manuscript p. 5 | lines 14–23

The rating procedure carries substantial bias risk that is not acknowledged. The three raters were "expert clinicians from our team," were informed of the two prompting styles (blinded only to model identity), and rated outputs from a flow-chart condition that "was developed by our team." Team members therefore evaluated, unblinded, a manipulation their own group designed: a direct expectancy-bias pathway, particularly for the "Fidelity to Prompt" metric, where the flow-chart condition scored notably higher (4.33 vs 3.04, Table 1). Additionally, the six Likert items were averaged into a single overall score per dialogue with no reported reliability analysis (no ICC for inter-rater agreement, no Cronbach's alpha for the composite), so it is unknown whether the items measure one construct or whether raters agreed. Finally, the "empathy" metric was excluded on the grounds that the scenarios "prioritized medical expertise over interpersonal dynamics," yet the second scenario requires informing parents of a medical error that caused their child's anaphylaxis, a task in which interpersonal and communication quality is central. Please justify the exclusion or reinstate the metric.

## Comment 5: manuscript p. 5 | lines 47–59; manuscript p. 6 | lines 33–40; manuscript p. 8 | lines 4–15

The unit of analysis leaves the study severely underpowered for the inferences attempted. Treating each LLM as a participant yields n=4 for a 3x2x2 repeated-measures ANOVA with error degrees of freedom as low as 3; in this regime the reported "trends" (rater p=.07, prompt style p=.06) are uninterpretable, and a null result cannot distinguish "no effect of prompting" from "no power to detect an effect." Notably, the authors themselves propose the better design in the Discussion: generating many outputs per condition and analyzing at the output level with raters as a random effect. That design should have been the study. As reported, the appropriate conclusion is not "prompting style does not affect quality" but "this study could not detect an effect with four models." Please reframe accordingly or collect the output-level data the Discussion already argues for.

## Comment 6: manuscript p. 4 | lines 7–25 and 50–53; manuscript p. 8 | lines 18–27

The study is not reproducible as reported. The models are identified only as "free versions" of ChatGPT, Claude, Copilot, and DeepSeek, with no model version, knowledge cutoff, generation date, temperature or sampling settings, or account tier details, and the manuscript itself notes that models are "increasingly being iterated, improved, and trained on," which further undermines reproducibility when versions are unspecified. The standardized prompt and the flowchart are said to be in supplementary materials that were not provided for review. For LLM evaluation studies in biomedicine, the TRIPOD-LLM reporting guideline (https://www.nature.com/articles/s41591-024-03425-5), a 19-item consensus checklist covering exactly these elements (model version, hyperparameters, prompting details, output variability), is now the expected standard. Please report the study against TRIPOD-LLM and supply the full prompts, the flowchart, model versions, generation settings, and dates.

**Relevant literature:** Gallifant J, et al. The TRIPOD-LLM reporting guideline for studies using large language models. *Nat Med.* 2025. (https://www.nature.com/articles/s41591-024-03425-5)

## Comment 7: manuscript p. 4 | lines 12–18

The Gemini safety refusal is treated as a mere substitution note, but it is arguably one of the study's most informative findings. A frontier model refused to generate pediatric emergency-scenario dialogue on safety grounds while its competitors complied, which is directly relevant to educators choosing models for simulation content, and it raises questions the manuscript never addresses: what refusal policies govern educational content generation, whether refusals are consistent across scenarios, and whether DeepSeek (the replacement, chosen because it "has been used in similar studies") differs systematically in safety tuning, capability, or training in ways that confound the model comparison. To be blunt, the substitution is not neutral: researchers have documented censorship-like refusal behavior in DeepSeek's R1 on topics politically sensitive in China, Tiananmen Square among them (https://arxiv.org/abs/2505.12625), behavior the authors attribute to training and alignment choices rather than capability limits. Whatever one thinks of the underlying content policy, the methodological point stands: the four-model comparison now mixes systems with structurally different refusal behaviors, assembled after observing a refusal. At minimum, please report the refusal verbatim, discuss its implications for deployability, and acknowledge that substituting models after observing refusals introduces selection bias into the four-model comparison.

## Comment 8: manuscript p. 2 | lines 22–32; manuscript p. 8 | lines 30–47

The conclusions overreach the data. The abstract and Discussion state that the findings "should guide clinicians and educators in choosing LLM and prompting strategies," but the study found no quality difference between prompting styles, no model reached the adopted quality threshold, and the design cannot support strategy recommendations from 16 dialogues rated by the unblinded study team. The claim that scores "came close" to the 4.5 threshold is doing considerable rhetorical work: Table 1 means range from 3.04 to 4.38, and the threshold itself is acknowledged (commendably) to have no derived basis in Haider et al. A null, underpowered comparison of two prompt-wording conditions does not yield guidance on "choosing LLM and prompting strategies." Please revise the conclusions to state what was actually shown: that in this small sample, neither approach produced dialogues meeting the adopted quality bar, and prompting style affected length but not rated quality.

**Relevant literature:** Haider SA, et al. Synthetic Patient-Physician Conversations Simulated by Large Language Models: A Multi-Dimensional Evaluation. *Sensors.* 2025;25(14):4305. (https://www.mdpi.com/1424-8220/25/14/4305), the reference study whose metrics and 4.5 benchmark this manuscript adopts.

## Comment 9: manuscript p. 3 | lines 44–49

The manuscript mischaracterizes the reference study on which its metrics and benchmark are based. It describes Haider et al. [5] as using "4 popular LLMs (ChatGPT, Claude, Copilot, and Gemini) to simulate dialogues between patient and physician for 10 different cardiac procedures," but the cited paper, verified at the publisher (https://www.mdpi.com/1424-8220/25/14/4305), evaluated ChatGPT 4.5, ChatGPT 4o, Claude 3.7 Sonnet, and Gemini Pro 2.5 generating transcripts for ten plastic surgery scenarios (abdominoplasty, blepharoplasty, facelift, hand surgery, lymphedema surgery, breast reconstruction, rhinoplasty, breast augmentation, liposuction, and mastopexy). Copilot was not among the models tested, and there were no cardiac procedures. The cover letter repeats the "cardiac surgery procedures" description. Because the manuscript presents itself as extending this work, please correct the description of the reference study throughout, and double-check that no other claims attributed to it (including the 4.5 benchmark) are similarly misremembered.

---

## Minor Comments

1. **Typo:** manuscript p. 6 line 10, "Table 1showcases" is missing a space.
2. **Text–table mismatch:** manuscript p. 6 lines 10–12 first states "We report average ratings for each metric by Prompting Condition" and then says "Table 1 showcases mean and SD ratings across metric by LLM." Table 1 (manuscript p. 12) is organized by prompt condition, not by LLM; please correct the second sentence.
3. **Statistics formatting:** manuscript p. 6 lines 25–27 reports "M = 1453 , SD = 762" with spaces before commas; please use consistent APA style throughout (M = 1453, SD = 762).
4. **Hyphenation:** "zero shot" (manuscript p. 3 line 51; p. 7 line 33) and "text based" (manuscript p. 3 line 58) should be "zero-shot" and "text-based."
5. **Timing:** the abstract (manuscript p. 2 lines 13–14) and Methods (manuscript p. 4 line 7) state only "Study was done in 2026." Given model versioning, please specify the months/weeks of data generation.
6. **Model specification:** "free versions of each model" (manuscript p. 4 line 21) should name the exact tier and version for each of the four models.
7. **Figure 1** (manuscript p. 11): the caption reads "Plot of average scores by metric across Prompt Condition"; please ensure the figure includes error bars or another uncertainty display and a clear legend, consistent with Table 1.
8. **Vague language:** "although they came close" (manuscript p. 8 line 43) should be quantified against the threshold.
9. **Reference 11** (manuscript p. 9 lines 53–56): the *Scientific Reports* citation is missing year, volume, and pages/article number.

---

## Suggested Editorial Disposition

**Reject in current form.** The question is reasonable and the reporting is admirably honest in places (the Gemini refusal, the un-derived benchmark), but the manuscript has three problems that revision of the text cannot fix: (1) it tests only prompt wording in consumer chat windows, without engaging any contemporary method for reliable, deterministic AI-generated content; (2) the statistics contain material errors (eta-squared values inconsistent with the F statistics; Poisson fit to massively overdispersed counts with no diagnostics) and the design is severely underpowered with unblinded team raters evaluating their own manipulation; and (3) the conclusions recommend prompting strategies on the basis of a null result from 16 dialogues. A substantially different manuscript could be valuable if it reports output-level data with blinded independent raters, fully specified model versions and settings per TRIPOD-LLM, and comparison conditions reflecting current practice for reliable generation (structured outputs, grounded generation) rather than prompt phrasing alone.

---

## Key External Sources Used in This Review

- Haider SA, Prabha S, Gomez-Cabello CA, et al. Synthetic Patient-Physician Conversations Simulated by Large Language Models: A Multi-Dimensional Evaluation. *Sensors.* 2025;25(14):4305. (https://www.mdpi.com/1424-8220/25/14/4305)
- Gallifant J, et al. The TRIPOD-LLM reporting guideline for studies using large language models. *Nat Med.* 2025. (https://www.nature.com/articles/s41591-024-03425-5)
- Model Context Protocol: open standard for connecting AI applications to external tools, resources, and data through explicit, versioned interfaces. (https://modelcontextprotocol.io/)
- Naseh A, Chaudhari H, Roh J, Wu M, Oprea A, Houmansadr A. R1dacted: Investigating Local Censorship in DeepSeek's R1 Language Model. arXiv:2505.12625 [cs.CL]. 2025. (https://arxiv.org/abs/2505.12625)
