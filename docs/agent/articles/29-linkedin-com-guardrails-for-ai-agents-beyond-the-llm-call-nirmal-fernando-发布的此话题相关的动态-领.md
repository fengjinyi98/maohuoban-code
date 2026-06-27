# Guardrails for AI Agents Beyond the LLM Call | Nirmal Fernando 发布的此话题相关的动态 | 领英

- 来源链接：https://www.linkedin.com/posts/nirmalfdo_aiagents-enterprisearchitecture-aigovernance-activity-7461373533756035072-x_O1
- 浏览器最终地址：https://www.linkedin.com/posts/nirmalfdo_aiagents-enterprisearchitecture-aigovernance-activity-7461373533756035072-x_O1
- 原始收集：docs/agent/3.md:56
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：Quick architecture question for anyone building AI agents in production:

Where do your guardrails actually live?

If the answer is "around the LLM call," I'd gently suggest that's the easy half. The harder half, and the one I keep seeing under-invested in, is everywhere else the agent reaches.

An agent is an orchestrator. It calls a model, sure, but it also reads memory, invokes tools, and sometimes hands off to other agents. Every one of those is a trust boundary, and the failure modes are not the same:

A bad LLM output is usually recoverable. You can re-prompt, validate schema, ground against sources.

A bad tool call is often not. The email is sent, the record is deleted, the payment is initiated.

That asymmetry is why I've started drawing guardrails on every wire, not just the model wire (diagram below). The one that earns its keep most often, in my experience, is the tool guardrail: parameter validation, authorization scoped to the actual user, policy thresholds, and human approval for the irreversible stuff.

The pattern I've landed on for regulated environments: an API gateway as the enforcement point in front of every tool (parameter validation, authz, rate limits, audit), a centralized policy engine behind it for the decisions that need to stay consistent across tools, and identity that flows end-to-end so the gateway is authorizing on behalf of the user, not the agent. Human approval as a separate workflow the gateway can route to when policy says "needs a human."

The failure mode I'd warn against is per-tool middleware where each team implements their own authorization logic. Looks simpler at first, becomes impossible to audit.

Curious to know your observations. Please leave a comment.

#AIAgents #EnterpriseArchitecture #AIGovernance| 领英上有 11 条评论

---

## 原始备注

https://www.linkedin.com/posts/nirmalfdo_aiagents-enterprisearchitecture-aigovernance-activity-7461373533756035072-x_O1（或搜索同主题）

## 正文

Guardrails for AI Agents Beyond the LLM Call
此标题由 AI 根据以下动态总结生成。
Nirmal Fernando
1 个月

Quick architecture question for anyone building AI agents in production:

Where do your guardrails actually live?

If the answer is "around the LLM call," I'd gently suggest that's the easy half. The harder half, and the one I keep seeing under-invested in, is everywhere else the agent reaches.

An agent is an orchestrator. It calls a model, sure, but it also reads memory, invokes tools, and sometimes hands off to other agents. Every one of those is a trust boundary, and the failure modes are not the same:

A bad LLM output is usually recoverable. You can re-prompt, validate schema, ground against sources.

A bad tool call is often not. The email is sent, the record is deleted, the payment is initiated.

That asymmetry is why I've started drawing guardrails on every wire, not just the model wire (diagram below). The one that earns its keep most often, in my experience, is the tool guardrail: parameter validation, authorization scoped to the actual user, policy thresholds, and human approval for the irreversible stuff.

The pattern I've landed on for regulated environments: an API gateway as the enforcement point in front of every tool (parameter validation, authz, rate limits, audit), a centralized policy engine behind it for the decisions that need to stay consistent across tools, and identity that flows end-to-end so the gateway is authorizing on behalf of the user, not the agent. Human approval as a separate workflow the gateway can route to when policy says "needs a human."

The failure mode I'd warn against is per-tool middleware where each team implements their own authorization logic. Looks simpler at first, becomes impossible to audit.

Curious to know your observations. Please leave a comment.

#AIAgents #EnterpriseArchitecture #AIGovernance

44
11 条评论
赞
评论
分享
Burhan Yanbolu
1 个月

This is the right architecture. Guardrails on the model wire alone miss the irreversible actions — tool calls, API requests, data access. We built exactly this pattern: centralized enforcement at every boundary (certification before access, budget circuit-breaking at runtime, scope validation per data request, and attestation proving the agent hasn't changed since approval). The per-tool middleware anti-pattern is real — impossible to audit at scale. Centralized policy with identity flowing end-to-end is the only way it works.

赞
回复
1 次回应
Craig Mallinson
1 个月

Most teams draw guardrails around the model because that’s the visible part. But the real asymmetry isn’t between “good output” and “bad output” — it’s between reversible and irreversible actions. Once an agent crosses a boundary where a tool call creates a real-world consequence, the question isn’t “did the model behave?” It’s “does this action still have the right to execute at the moment it binds?”

That’s where drift happens — authority, admissibility, dependency state, and legitimacy can all shift between proposal and consequence. Guardrails on the wires help, but without execution‑time validation you’re still trusting upstream assumptions. In my experience, the only layer that consistently prevents irreversible failures is checking the truth of the action at the bind‑moment itself.

赞
回复
Josh Bagley
1 个月

Agree, adding guardrails to your architecture helps ensure your remembering to access vulnerabilities at each sector of your agentic workflow. More of a zero-trust approach. 

There are also many areas outside those guardrails to be concerned about, areas I'm currently working on...
- Guarding against indirect prompt injection from the memory store itself. Memory storage should be considered untrusted. 
- Adding agent loop protection and enforce thresholds, to prevent infinite reasoning loops.
- Semantic validation steps and checks to verify agents chosen actions against a deterministic state-machine. Ensure what is being acted on is valid, validate the intent not just the parameters.
- Use of a tiered inline checks to avoid latency, use deterministic schema and validation checks before hand. Evaluations at each layer can impact performance  extremely. 
- Define multi-agent contracts / handoffs between agents, agents should validate the data exactly as a user is expected to do.

赞
回复
1 次回应
Kalhara Dasanayaka
1 个月

Fully agree, most teams over focus on LLM guardrails and ignore the real risk: tool execution.
One thing I’d add is observability + simulation. Without seeing why agents act and testing safely, even good guardrails can fail silently.

赞
回复
Lali Devamanthri
1 个月

I'm more concerned about looped agent's financial cost :) 
Until MCP get matures, would have to depend on AD+OPA+APIGW

赞
回复
1 次回应
Peter Carroll
1 个月

Use CoralOS, does the hardwork for you CoralOS 

赞
回复
查看更多评论

要查看或添加评论，请登录

最相关的动态
Josh Bagley
1 个月

Agree, adding guardrails to your architecture helps ensure your remembering to access vulnerabilities at each sector of your agentic workflow. More of a zero-trust approach. 

Nirmal Fernando

Director - Head of Engineering, Solutions BU @ WSO2 | Driving Technical Leadership

1 个月

Quick architecture question for anyone building AI agents in production:

Where do your guardrails actually live?

If the answer is "around the LLM call," I'd gently suggest that's the easy half. The harder half, and the one I keep seeing under-invested in, is everywhere else the agent reaches.

An agent is an orchestrator. It calls a model, sure, but it also reads memory, invokes tools, and sometimes hands off to other agents. Every one of those is a trust boundary, and the failure modes are not the same:

A bad LLM output is usually recoverable. You can re-prompt, validate schema, ground against sources.

A bad tool call is often not. The email is sent, the record is deleted, the payment is initiated.

That asymmetry is why I've started drawing guardrails on every wire, not just the model wire (diagram below). The one that earns its keep most often, in my experience, is the tool guardrail: parameter validation, authorization scoped to the actual user, policy thresholds, and human approval for the irreversible stuff.

The pattern I've landed on for regulated environments: an API gateway as the enforcement point in front of every tool (parameter validation, authz, rate limits, audit), a centralized policy engine behind it for the decisions that need to stay consistent across tools, and identity that flows end-to-end so the gateway is authorizing on behalf of the user, not the agent. Human approval as a separate workflow the gateway can route to when policy says "needs a human."

The failure mode I'd warn against is per-tool middleware where each team implements their own authorization logic. Looks simpler at first, becomes impossible to audit.

Curious to know your observations. Please leave a comment.

#AIAgents #EnterpriseArchitecture #AIGovernance

1
赞
评论
分享

要查看或添加评论，请登录

Hari Krishna
1 个月

If your Architecture Review Board (ARB) evaluates an LLM or Agentic workflow the same way it reviews a traditional web app, you are exposing your firm to systemic risk.

Traditional ARBs look for deterministic outcomes. Generative AI is inherently non-deterministic.

To scale enterprise AI safely, you must inject an automated AI Intake Workflow into your ARB operating model. 

Here is the architectural verification matrix every senior architect must mandate:

1. THE PROMPT & FIREWALL GATE
- Demand complete separation of System Prompts from User Inputs. System prompts must be managed via standard CI/CD pipelines, never hardcoded.
- Enforce an input injection firewall to sanitize incoming payloads for adversarial context manipulation.

2. THE DETERMINISTIC FALLBACK PATTERN
- Never allow an AI model to operate without a hard-coded fallback boundary.
- If the model’s confidence score or semantic classification falls below a defined threshold (e.g., 0.85), the architecture must gracefully degrade to a deterministic rule-engine or route to a human operator.

3. THE CONTEXT DEGRADATION AUDIT
- Review how the solution handles vector storage drift and context-window saturation. 
- Ensure a clear decoupling of the orchestration layer (e.g., LangChain/Semantic Kernel) from the underlying LLM provider to protect against vendor lock-in.

Modern governance isn’t about saying "No" to AI innovation, it’s about engineering the boundaries that make "Yes" safe.

#ArchitectureGovernance #ARB #AIGovernance #SolutionArchitecture #TOGAF #EnterpriseArchitecture

43
4 条评论
赞
评论
分享

要查看或添加评论，请登录

Pavan Dev Singh C.
3 周

Today we're launching the Parmana Documentation Platform.
https://lnkd.in/g7jgtM3q

AI is becoming increasingly capable of taking actions, not just generating content. But before AI can operate in high-trust environments, organizations need a way to prove that decisions were made under the right rules, with the right controls, and can be independently verified.
That's what Parmana is built for.

The documentation site includes:
• Getting started guides
• SDK documentation
• Architecture and governance concepts
• Deployment and verification workflows
• Whitepapers and technical research
• Compliance, auditability, and trust infrastructure resources

Parmana is deterministic governance infrastructure for AI-driven decisions.
Every decision is:
✓ Governed
✓ Auditable
✓ Verifiable
✓ Enforceable

If you're working on AI governance, compliance, safety, financial systems, healthcare, or automated decision-making, I'd love your feedback.
AI can recommend. Parmana decides.

#AI #AIGovernance #AIInfrastructure #Compliance #TrustInfrastructure #SystemsEngineering #DeveloperTools

Parmana Systems - Parmana Systems
docs.manthan.systems
2
赞
评论
分享

要查看或添加评论，请登录

Enforra

420 位关注者

1 个月

If you are building production AI agents, here is a distinction worth getting precise about: authorization vs runtime control.

Authorization is identity and permission resolution. OAuth scopes, API keys, role-based access. It answers whether a principal has permission to use a resource. It runs at setup, or at the start of a session.

Runtime control is enforcement at the point of execution. It answers whether a specific action, with specific parameters, in a specific context, should proceed, be blocked, or be escalated for human approval.

In traditional software, authorization covers most of the surface area. Code is deterministic. A function call with a given input produces a known output. You can reason about the full call graph at build time.

Agents are different. An LLM-driven agent constructs its own tool calls at inference time. The parameters are generated dynamically. The sequence of actions is not fixed. The agent can reach conclusions and take actions that were not explicitly encoded by the developer.

That means your authorization layer, which was designed around known actors making predictable requests, is no longer sufficient.

What you need is a runtime layer that can:

 • Evaluate tool call intent and parameters against a policy
 • Enforce fine-grained constraints (not just "can this agent use the database tool" but "can it run this query on this table with these values")
 • Pause execution and route to a human approval queue when the action crosses a threshold
 • Produce a structured audit log of every action taken, blocked, or escalated

This is what Enforra enforces. A policy engine that runs at agent execution time, not at setup time.

Authorization remains part of the stack. Runtime control is the layer that makes agent behavior safe and auditable once the agent is actually working.

#AIAgents #AgentSecurity #RuntimeControl #MCPSecurity #AIInfrastructure #AIEngineering #LLMOps #AgenticA #DeveloperTools #AIStartups #AIGovernance #FounderLed #BuildingInPublic #AIPolicy #StartupInfrastructure

3
赞
评论
分享

要查看或添加评论，请登录

Nikhil Agrawal
1 个月

How much of your agentic pipeline's complexity exists just to hold down token costs?

Four Chinese labs released frontier-class open-weights models in a 17-day window.

GLM-5.1. MiniMax M2.7. Kimi K2.6. DeepSeek V4.

Permissive licenses. API pricing between $1.50 and $3.50 per million output tokens — with cheaper variants well below $1. Self-hosted at scale, you're looking at hardware cost only.

Claude Opus 4.7 is $25/M output.

When tokens are expensive, you design agents to be terse:
→ Short chain-of-thought
→ Compressed tool results
→ Routing logic to push cheap tasks to smaller models
→ Per-step token budgets baked into every node

At 5–15x cheaper on API, that calculus shifts.

Let the agent think. Longer plans. Richer intermediate state. More reasoning steps per dollar. A lot of what you engineered to contain costs simply becomes unnecessary.

The catch: a 700B to 1.6T MoE model is not `docker run`.

Multi-node tensor parallelism, cross-node KV cache management, vLLM or SGLang configured for your specific hardware. The inference stack is real work.

For enterprises with data residency requirements, that work is worth doing once. Frontier capability on your own infrastructure, at hardware cost — no per-token API relationship.

The cost floor just moved. The architecture assumptions built on top of the old floor are worth revisiting.

Manan Dubey Jurisynk Synk AI Consultancy
#OnPremAI #AgenticSystems #EnterpriseAI

10
赞
评论
分享

要查看或添加评论，请登录

AI Shield – Compliance Auditor

7 位关注者

2 周

Data Protection by Design: The engineering mandate for zero-data-storage security.

When evaluating Data Loss Prevention (DLP) frameworks for Generative AI, traditional proxy architectures introduce severe operational liabilities: network latency, high infrastructure costs, and the risk of creating a secondary point of data aggregation.

AI Shield mitigates these deficiencies through a distributed, privacy-first technical architecture:

- Edge Tokenization: Contextual scanning algorithms execute locally within the browser sandbox environment.

- Zero External Retention: Prompt content is never captured, stored, or transmitted to AI Shield servers.

- Metadata Integration: Only anonymized telemetry and structural indicators are sent to the central audit dashboard.

By processing risk metrics exclusively at the edge, organizations preserve absolute data sovereignty while maintaining maximum network performance. Technical specifications available at getaishield.co.

AI Shield: Data Loss Prevention for AI Tools
getaishield.co
1
赞
评论
分享

要查看或添加评论，请登录

Muhammad Asim
4 周

LLM integration in production requires deterministic guardrails.

While building an automated support agent, context window overflow caused unpredictable API costs and truncated responses. Relying on the model to summarize its own history introduced latency and hallucination risks that disrupted the user experience during peak traffic.

I shifted from simple context concatenation to a rolling window strategy combined with a vector database for semantic retrieval. This approach ensures only relevant metadata and recent history enter the prompt, maintaining response quality while controlling token consumption and reducing latency across the system.

- Use semantic search to inject only relevant context.
- Implement token-counting middleware to prevent API overflows.
- Decouple prompt engineering from application logic for easier testing.

How do you manage context window limits in your production AI agents?

#aiengineering #llms #softwarearchitecture #typescript #backend #automation #MuhammadAsim #MehfilAI

3
赞
评论
分享

要查看或添加评论，请登录

logiQode
2 周

**You wouldn't run a microservices cluster without observability. So why are teams shipping AI agents with none?**

Frameworks like CrewAI, AutoGen, and LangGraph have moved fast from experimental to production. But the tooling around them — monitoring, tracing, and failure detection — hasn't kept pace.

The core problem: agents are non-deterministic by design. A traditional service either returns a 200 or it doesn't. An agent can return a 200, spend 40 seconds doing it, silently hallucinate a tool call, and still look "successful" from the outside.

In practice, teams running multi-agent pipelines often discover issues only after they surface downstream:

▸ An orchestrator agent loops without a termination condition
▸ A retrieval step silently returns empty context, poisoning every downstream response
▸ Token costs spike overnight because one prompt grew unbounded

Production-grade agent observability is closer to **distributed tracing** than classic application monitoring. You need span-level visibility into each agent's decisions, tool invocations, and handoffs — not just endpoint latency.

Tools like LangSmith, Arize, and OpenTelemetry-based adapters are starting to fill this gap. But instrumentation still requires deliberate engineering effort — it won't happen automatically just because you're using a popular framework.

The teams getting this right treat agent monitoring as a **first-class engineering concern** from day one, not an afterthought bolted on after something breaks.

What's your current approach to observability in agentic systems?

#artificialintelligence #llm #agenticai #observability #softwareengineering

1
赞
评论
分享

要查看或添加评论，请登录

Michael Ciuman
3 周

When the policy is fuzzy, you write code. When the code is right, you push the boundary.

It’s Saturday night, and while the industry is sleeping on the conceptual definition of "AI verification loops," the Blaze engine just cleared its v112 Final Non-Authority Closure Preview.

The math doesn't care about the weekend.

We aren't just checking if an endpoint boundary holds anymore. By v112, the state machine is performing deep recursive lineage validation—cryptographically verifying the integrity of 6 consecutive generation states (v106 through v111) before the current state machine is even allowed to advance a single step.

The State Control: Complete non-authority closure. errors: [] straight down the line.

The Boundary Enforcement: Zero token exposure, zero hidden mutation webhooks, zero raw payload leakage. The outcome isn’t an option; it’s a deterministic floor.

The Velocity: Moving from yesterday's single-binding previews straight through to multi-generational lineage validation in under 48 hours.

If your governance solution requires a human compliance audit or a software linter checking prompts after the fact, you haven't built architecture—you've built an alarm bell. True security means the execution corridor physically refuses to compile without the receipt chain.

Going back to the terminal. Might try to cross the v120 execution threshold before logging off for the night.

The receipts don't sleep.

…展开
1
1 条评论
赞
评论
分享

要查看或添加评论，请登录

2,111 位关注者

509 则动态
4 篇文章
查看档案  关注
更多文章
CMS-0057-F Is Not a FHIR Problem. Stop Pretending It Is.
Nirmal Fernando  2 个月
Converting your clinical policies into FHIR Questionnaires is one of the hardest parts of CMS-0057-F compliance. Here's why — and what you can do.
Nirmal Fernando  4 个月
Open source middleware platform for healthcare
Nirmal Fernando  10 个月
探索相关领域
Building Guardrails with AI Language Models
How to Use AI Guardrails for Data Security
Building Reliable LLM Agents for Knowledge Synthesis
AI Guardrails for High-Risk Use Cases
How to Build Reliable LLM Systems for Production
How to Set Generative AI Guardrails
展开 
浏览内容分类
Career
Productivity
Finance
Soft Skills & Emotional Intelligence
Project Management
Education
展开
