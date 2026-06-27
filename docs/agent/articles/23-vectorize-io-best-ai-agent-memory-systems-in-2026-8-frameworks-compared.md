# Best AI Agent Memory Systems in 2026: 8 Frameworks Compared

- 来源链接：https://vectorize.io/articles/best-ai-agent-memory-systems
- 浏览器最终地址：https://vectorize.io/articles/best-ai-agent-memory-systems
- 原始收集：docs/agent/3.md:38
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：Your AI agent forgets everything between sessions. We ranked the 8 best agent memory systems in 2026 — Hindsight, mem0, Zep, Letta, Cognee, and more — with architecture breakdowns, real code, and a decision guide.

---

## 原始备注

https://vectorize.io/articles/best-ai-agent-memory-systems

## 正文

Best AI Agent Memory Systems in 2026: 8 Frameworks Compared
March 14, 2026

Most AI agents have no persistent memory — every session starts from scratch. This guide ranks the 8 best agent memory systems available in 2026, with architecture breakdowns, code examples, and a decision guide to help you pick the right one.

Do You Actually Need AI Agent Memory?

Before diving into frameworks, a quick gut check. You likely need an AI agent memory system if:

Your agent runs repeatedly on related tasks (same domain, same users, same workflows)
Humans correct the agent and those corrections should stick
Domain rules evolve over time and the agent needs to track changes
The agent interacts with persistent entities — vendors, repos, customers, projects
You're paying significant token costs re-injecting the same context every call

You probably don't need one if your agent is stateless, single-session, or handles each request independently with no carryover. In that case, memory adds complexity without benefit.

If any of the above apply, read on.

Quick Comparison
Framework	Memory Class	Architecture	Open Source	Stars	Lock-in	Managed Cloud	Self-Host
Mem0	Personalization + some institutional	Vector + Graph	Apache 2.0	~48K	None	Yes	Yes
Hindsight	Both (built for institutional)	Multi-strategy hybrid	MIT	~4K (growing fast)	None	Yes	Yes
Letta	Both	Tiered (OS-inspired)	Apache 2.0	~21K	None	Yes	Yes
Zep / Graphiti	Both (strongest on temporal)	Temporal KG	Graphiti: open	~24K	None	Yes	Via Graphiti only
Cognee	Institutional	KG + Vector	Open core	~12K	None	Yes	Yes
SuperMemory	Personalization + some institutional	Memory + RAG	No	—	None	Yes	Enterprise only
LangMem	Personalization	Flat key-value + vector	MIT	~1.3K	LangGraph	No	Yes
LlamaIndex Memory	Personalization	Composable buffers	MIT	Part of ~48K	LlamaIndex	Via LlamaCloud	Yes
The Problem: Your AI Agent Has Amnesia

AI agent memory is the ability of an AI agent to store, retrieve, and reason over information across interactions, sessions, and tasks. It transforms stateless LLMs into persistent systems that learn from experience, retain user context, and compound domain knowledge over time.

Without it, your AI agent can't remember what it did yesterday or even an hour ago. Until recently, most teams solved this with chat history buffers — store the last N messages, maybe summarize older ones, move on. That was fine when agents were glorified chatbots.

But as AI agents moved from demos to real workflows — procurement, code review, research, operations — chat buffers stopped being enough. The field has since split into two categories: AI agent memory frameworks that handle conversation context and those that handle accumulated operational knowledge. Understanding that split is key to choosing the right one.

The Personalization Problem

Your agent doesn't remember who it's talking to. Users re-explain their preferences every session. The support bot asks the same clarifying questions it asked yesterday. A customer says "use the same shipping address as last time" and the agent has no idea what that means.

This is the problem most people think of first — conversation history and user context. It's real, and it matters. But it's the simpler of the two problems.

The Institutional Knowledge Problem

This is the harder one, and it's what separates a demo agent from one that does real work.

Consider an agent deployed to handle procurement workflows. On day one, it processes a purchase order and makes mistakes. A human corrects it: vendor X requires a specific PO format, approvals over $50K need different routing, and Q4 budget reviews always slip by two weeks so don't schedule dependent work against the published deadline.

The agent gets it right. Then the session ends. Next run, it starts from zero. Same mistakes. Same corrections. It learned nothing.

A human employee doesn't work this way. Over weeks and months, they build institutional knowledge — the exceptions, the unwritten rules, the patterns that only emerge from experience. They learn which vendors are slow to respond, which approval chains have bottlenecks, which stakeholders care about specific details. This accumulated understanding is what makes them effective.

Agents that do real work need the same capability. They need to:

Remember what they did — not just conversation transcripts, but the outcomes of their actions and the corrections they received
Extract lessons from experience — turning raw interaction history into structured knowledge about how to do their job better
Build a model of their domain — entities, relationships, and how they change over time (Alice was the budget owner until February, then it moved to Bob)
Compound knowledge across runs — each execution should make the next one better, not restart from scratch
Recall the right context at the right time — 10,000 stored facts are useless if the agent can't surface the three that matter for the current task

This goes well beyond conversation history. Raw chat logs are noise, not knowledge. What an agent needs is extracted, structured understanding that compounds over time — the difference between remembering everything that was said and actually learning from it.

Why This Is Hard

Context windows don't solve either problem. They're finite, expensive, and ephemeral. You can stuff 200K tokens into a prompt, but you're paying for every token on every call, and none of it persists.

What you need is an AI agent memory layer — something that extracts knowledge, stores it durably, and retrieves it when relevant. The problem is that "memory" means wildly different things depending on which framework you pick:

A conversation buffer that truncates old messages
A vector store that does cosine similarity over embeddings
A knowledge graph that tracks entities and relationships over time
A full extraction engine that identifies facts, resolves entities, and synthesizes across memories

These are not the same thing. A conversation buffer handles basic personalization. But it won't help your agent learn that Q4 budget reviews always slip by two weeks, or that vendor X's API returns different error codes on weekends. For that, you need something that extracts structured knowledge and makes it retrievable.

Here's a concrete example of where vector-only retrieval fails:

Your agent stored this fact three weeks ago: "Vendor X requires PO format v3 for all orders over $10K."

Today, a user asks: "Which vendors need special purchase order templates?"

A vector search may miss this entirely — "template" and "format" may not always be semantically close enough to surface the match. An entity-aware system connects both queries to Vendor X. A keyword index catches "purchase order." Multi-strategy retrieval finds it through at least two paths even when any single strategy fails.

You might wonder: "Couldn't I just use vector search plus an LLM summarization step?" Sometimes, yes. But summarization only works over what retrieval returns. If retrieval misses the relevant facts because of a terminology mismatch, there's nothing to summarize. The architecture of retrieval — not just what happens after — determines whether your agent can surface what it learned.

A note on terminology: Different communities describe this second AI agent memory problem differently — episodic memory, experiential learning, reflection pipelines, agent self-improvement. We use "institutional knowledge" because it captures the core idea: accumulated operational knowledge that makes an agent better at its job over time. Think of it like a new hire absorbing the unwritten rules of an organization.

This post compares 8 memory systems across the dimensions that actually matter — whether you're solving for personalization, institutional knowledge, or both.

How AI Agent Memory Works

Before comparing AI agent memory frameworks, it helps to understand the four core operations that every memory system performs — and how they fit together.

Ingestion (storing memories)

When an AI agent stores a memory, the system doesn't just dump raw text into a database. Better frameworks run an extraction pipeline. They identify discrete facts, resolve entities ("Alice" and "our CTO" → same person), assign timestamps, and generate embeddings. The output is structured knowledge, not a blob of text.

Storage

Extracted knowledge lands in one or more storage layers:

Vector store — embeddings for semantic similarity search
Knowledge graph — entities and relationships for structured traversal
Keyword index — BM25 or similar for exact term matching
Temporal metadata — timestamps and validity windows for time-aware queries

Not every framework uses all of these. Some use only vectors. Some combine vectors with graphs. The storage architecture determines what kinds of retrieval are possible.

Retrieval (recalling memories)

When an AI agent needs context, the memory system searches its storage. The simplest approach is vector similarity — embed the query, find the closest stored embeddings. More sophisticated AI agent memory systems run multiple strategies in parallel: semantic search, keyword matching, graph traversal, and temporal filtering. They then rerank the combined results for relevance.

Synthesis (reasoning across memories)

Some AI agent memory frameworks add a final step: pass retrieved facts to an LLM and ask it to reason across them. This is the difference between returning "here are 5 relevant facts" and answering "based on everything we know, here's what's going on." Synthesis adds latency since it requires a full LLM call. However, it produces answers that connect dots across scattered memories.

Not every framework implements all four stages. The comparison below shows which ones do.

How We Evaluated

We assessed each framework across eight dimensions:

Dimension	What We Looked At
Memory Class	Personalization (user prefs, conversation history), institutional knowledge (learned behavior, domain expertise, accumulated experience), or both
Open Source	License, self-host options, what's paywalled
Architecture	Vector-only, knowledge graph, tiered, hybrid
Retrieval Quality	Multi-strategy search, reranking, temporal awareness
Developer Experience	Time to first memory, SDK quality, documentation
Framework Lock-in	Works standalone or requires a specific ecosystem?
Production Readiness	Managed cloud, compliance certs, latency guarantees
Pricing	Free tier, scaling costs, pricing model
Community	GitHub stars, contributor count, ecosystem momentum
Performance	Retrieval latency, ingestion cost, storage growth, token overhead

Each architectural approach has a different latency profile. Rough ranges to keep in mind:

Operation	Typical Latency	Notes
Vector-only retrieval	~10–50ms	Single strategy, fastest but lowest recall quality
Graph traversal	~50–150ms	Entity/relationship lookups
Multi-strategy retrieval (parallel)	~100–600ms	Depends on number of strategies and reranking
LLM synthesis (e.g. reflect)	~800–3000ms	Full inference call, depends on model and provider
Memory ingestion (retain/add)	~500–2000ms	LLM-based extraction, typically done in background

A key architectural insight: well-designed AI agent memory systems optimize for fast reads at the cost of slower writes. Heavy lifting — fact extraction, entity resolution, embedding generation, graph construction — happens at write time so retrieval stays fast. This is the right tradeoff. Memories are typically written once (often in background processes) but read many times in latency-sensitive contexts.

The memory class distinction matters more than most teams realize. Personalization memory stores what a user prefers. Institutional knowledge memory stores what the AI agent has learned about how to do its job — extracted lessons, domain patterns, entity relationships, and corrections that compound over time. Some frameworks handle both. Others are built for one and awkwardly stretched to cover the other.

A note on benchmarks: LoCoMo and LongMemEval have become the de facto standard evaluations for AI agent memory systems. They test whether a framework can retrieve the right facts from long, complex interaction histories. However, both benchmarks focus exclusively on conversational data. As agents move beyond chatbots into real task execution, the field needs benchmarks that evaluate memory in the context of agent workflows, not just conversations. Watch for new evaluations that test whether memory actually helps agents perform tasks better over time.

The 8 Best AI Agent Memory Frameworks

1. Mem0

What it is: The most widely adopted AI agent memory framework. Built as a standalone memory layer that plugs into any LLM application.

Memory class: Personalization + some institutional. Strong on user/session memory. Graph features (Pro tier) add entity tracking, but the core product is built around personalization.

Architecture: Dual-store combining vector database and knowledge graph. An extraction pipeline converts conversation messages into atomic memory facts, scoped to users, sessions, or agents. Supports Qdrant, Chroma, Milvus, pgvector, and Redis as vector backends. On the graph side (Pro tier), memories are linked as entities with relationships. This enables structured traversal beyond pure similarity search. Memories are stored as atomic events with metadata for filtering by user, session, or application. A single Mem0 instance can serve multiple agents or user populations with scoped retrieval.

Strengths:

Largest community (~48K GitHub stars, 5,500+ forks)
Well-funded — YC-backed with a $24M Series A (October 2025, led by Basis Set Ventures), v1.0 shipped
Framework-agnostic — integrates with LangChain, CrewAI, LlamaIndex, and more
Python and JavaScript SDKs
SOC 2 and HIPAA compliance on the managed platform
Fastest path from zero to working memory (minutes)

Weaknesses:

Graph features (branded "Mem0g") require the $249/mo Pro tier (similarly, Zep gates advanced features behind its cloud offering)
49.0% on LongMemEval in independent evaluation (arxiv 2603.04814) — significantly below other dedicated memory systems; self-reported LOCOMO results have been disputed by competitors
Can feel too simplistic for real institutional knowledge use cases without the Pro tier
Steep pricing jump: free → $19/mo → $249/mo

Best for: Teams that want the largest ecosystem, broadest integrations, and a proven managed service. If you need knowledge graph features, budget for Pro.

When NOT to use Mem0:

Your primary need is institutional knowledge and you can't budget for Pro — graph features are where Mem0's institutional capabilities live
You need a lightweight, self-contained solution — Mem0 is a full platform that can feel heavyweight for simple use cases
You want to avoid vendor pricing risk — the jump from $19/mo to $249/mo is steep if your needs grow

Getting started:

pip install mem0ai
export OPENAI_API_KEY="YOUR_API_KEY"

from mem0 import Memory

memory = Memory()

# Store memories from conversation messages
messages = [
{"role": "user", "content": "I prefer dark mode and use Python for most projects."},
{"role": "assistant", "content": "Noted! I'll keep that in mind."}
]
memory.add(messages, user_id="alice")

# Retrieve relevant memories
results = memory.search(query="What programming language does the user prefer?", user_id="alice")
for entry in results["results"]:
print(entry["memory"])

Pricing: Free (10K memories) · $19/mo (50K) · $249/mo Pro (unlimited + graph)

2. Hindsight

What it is: An AI agent memory engine that handles both personalization and institutional knowledge, built with the harder problem first. Most memory frameworks started with conversation personalization and added knowledge features later. Hindsight was designed from the ground up to help agents extract lessons from experience, build domain understanding, and improve over time. It also handles user preferences and conversation context naturally. Built by Vectorize.io ($3.5M raised, April 2024) and battle-tested on Jerri, their internal AI project manager that compounds knowledge across weeks of meetings, decisions, and action items.

Memory class: Both — built for institutional knowledge. Fact extraction, entity resolution, and reflect are designed for agents that need to learn from experience and compound domain expertise. Personalization is handled naturally through the same pipeline.

Architecture: Four retrieval strategies run in parallel on every query:

Semantic search (embeddings)
BM25 keyword matching
Entity graph traversal
Temporal filtering

Results are reranked with a cross-encoder. On the ingestion side, Hindsight automatically extracts structured facts, resolves entities ("Alice" and "my coworker Alice" → same person), and builds a knowledge graph. This extraction pipeline is what turns raw interaction history into structured institutional knowledge — the agent doesn't store what was said, it stores what was learned.

What sets this AI agent memory system apart is reflect — a synthesis operation that reasons across memories using an LLM. Instead of returning a ranked list of facts, it produces a coherent answer that connects dots across your entire memory bank. This is critical for institutional knowledge. An agent handling procurement doesn't just need to retrieve individual facts about vendor X. It needs to synthesize across dozens of interactions to answer "what have we learned about working with vendor X?"

Strengths:

94.6% retrieval accuracy on LongMemEval — the top officially reproduced result on the Agent Memory Benchmark leaderboard (though the benchmark is increasingly saturated and limited to conversational data)
Built for institutional knowledge — fact extraction, entity resolution, and knowledge graph are core, not bolted on
reflect synthesizes across memories rather than just retrieving them — agents reason over accumulated experience
Multi-strategy retrieval catches what single-strategy systems miss (critical when queries use different terminology than stored knowledge)
Read-optimized architecture — fact extraction, entity resolution, and embedding happen at write time so recall stays fast (100–600ms typical). Writes are heavier but designed for background ingestion
Embedded PostgreSQL + pgvector — no external database setup
MCP-first design works with Claude, Cursor, VS Code, Windsurf, and any MCP client
Framework-agnostic: Python/TypeScript/Go SDKs, plus integrations for CrewAI, Pydantic AI, and LiteLLM
Self-hosted (one Docker command) or managed cloud
Supports 10+ LLM providers including Ollama for fully local, private deployments

Weaknesses:

Newer project (~4K GitHub stars, launched 2025), but community is growing fast
reflect adds latency since it makes an LLM call
Fact extraction quality depends on the configured LLM provider

Best for: Teams building AI agents that need both personalization and institutional knowledge — especially where the agent does real, repeated work and needs to improve over time. The combination of fact extraction, multi-strategy retrieval, and synthesis makes it stand out for agents that accumulate domain expertise.

When NOT to use Hindsight:

Your agent only needs short conversation memory within a single session — a simple buffer is lighter and faster
You don't need cross-session learning — if every request is independent, memory adds complexity without benefit
Retrieval latency must stay under ~50ms — multi-strategy retrieval with reranking typically runs 100–600ms (though this is sub-second and acceptable for most interactive use cases)
You want the absolute simplest infrastructure — Hindsight embeds Postgres, which is zero-config but heavier than an in-memory store
You're already deep in LangGraph or LlamaIndex and just need basic memory — their built-in options avoid adding another dependency

Getting started:

docker run --rm -it --pull always \
-p 8888:8888 -p 9999:9999 \
-e HINDSIGHT_API_LLM_API_KEY=YOUR_API_KEY \
-v $HOME/.hindsight-docker:/home/hindsight/.pg0 \
ghcr.io/vectorize-io/hindsight:latest

Three core operations:

from hindsight_client import HindsightClient

client = HindsightClient(base_url="http://localhost:8888", bank_id="my-project")

# Store — extracts facts, entities, relationships automatically
client.retain("Alice moved from the backend team to lead the ML platform migration.")

# Retrieve — 4 strategies in parallel, cross-encoder reranked
results = client.recall("Who is working on the ML platform?")

# Synthesize — LLM reasons across all relevant memories
summary = client.reflect("What organizational changes happened recently?")

Pricing: Free self-hosted · Usage based cloud service (free credits available) · Enterprise custom

3. Letta (formerly MemGPT)

What it is: An AI agent runtime with an OS-inspired memory architecture. Not just a memory layer — it's a full platform where agents manage their own context.

Memory class: Both. Agents actively manage what stays in context (personalization) and what gets archived for long-term retrieval (institutional). The self-editing memory model means the agent decides what knowledge to preserve.

Architecture: Three tiers inspired by how operating systems manage memory:

Core memory — always in the LLM's context window (like RAM)
Recall memory — searchable conversation history (like disk cache)
Archival memory — long-term storage the agent can query (like cold storage)

The key insight: agents actively decide what to keep in context versus archive. They self-edit their own memory blocks using tools.

Strengths:

Innovative architecture
Well-funded — $10M seed led by Felicis Ventures ($70M post-money valuation), backed by Jeff Dean (Google DeepMind), Clem Delangue (Hugging Face), and Ion Stoica
Agents manage their own memory (not just passive storage)
Agent Development Environment (ADE) for visual debugging and memory inspection
Model-agnostic (OpenAI, Anthropic, Ollama, Vertex AI, and more)
Based on a peer-reviewed research paper

Weaknesses:

You're adopting a runtime, not just a library — heavier commitment
Steeper learning curve (hours to set up, not minutes)
More complex deployment than simpler memory layers

Best for: Teams building agents that need to actively manage their own context. If you want agents that reason about what to remember and what to forget, Letta's architecture is unique.

When NOT to use Letta:

You want a memory layer, not a runtime — Letta is a full agent platform, and adopting it just for memory is like buying an OS for its file system
Setup time matters — expect hours, not minutes, to get productive
You need a lightweight library you can plug into an existing agent framework — Letta wants to be the framework

Getting started:

pip install letta-client
docker run -d --name letta-server \
-p 8283:8283 \
-e OPENAI_API_KEY="YOUR_API_KEY" \
letta/letta:latest

from letta_client import Letta

client = Letta(base_url="http://localhost:8283")

# Create an agent with persistent memory blocks
agent = client.agents.create(
model="openai/gpt-4o-mini",
embedding="openai/text-embedding-3-small",
memory_blocks=[
{"label": "human", "value": "The user's name is Alice. She works on ML infrastructure."},
{"label": "persona", "value": "I am a helpful project assistant."},
],
)

# Send a message — the agent can self-edit its memory blocks
response = client.agents.messages.create(
agent_id=agent.id,
messages=[{"role": "user", "content": "Actually, I moved to the platform team last week."}],
)

Pricing: Free self-hosted · $20–200/mo managed cloud

4. Zep / Graphiti

What it is: A temporal knowledge graph engine for agent memory. Zep Cloud is the commercial product; Graphiti is the open-source graph engine underneath.

Memory class: Both — strongest on temporal institutional knowledge. Tracks how entities and relationships change over time with validity windows. Also handles conversation memory and user context.

Architecture: Episodes (text or JSON) are ingested and automatically decomposed into entities, edges, and temporal attributes. Unlike static knowledge graphs, every fact carries validity windows — when it became true and when it was superseded. Temporal edges are indexed using interval trees for efficient historical queries. The system can answer "who was the project lead in January?" differently from "who is the project lead now?" Built on a peer-reviewed architecture (arxiv 2501.13956).

Strengths:

Best temporal awareness in the space — nothing else tracks fact evolution this well
63.8% on LongMemEval (GPT-4o), with strong improvements in temporal reasoning and single-session preference categories
<200ms retrieval latency on cloud
Python, TypeScript, and Go SDKs
SOC2 Type 2 and HIPAA compliance
Strong entity and relationship modeling
Graphiti has ~24K GitHub stars — significant open-source presence

Weaknesses:

Zep Community Edition has been deprecated — self-hosting Zep with full features is no longer available. You must use Zep Cloud (managed) or build directly on the open-source Graphiti library
Credit-based pricing requires careful usage estimation
Steeper learning curve than simpler memory layers
Minimal free tier (1K credits)

Best for: Applications where entities and relationships change over time — CRM assistants, compliance agents, medical record systems. If your agent needs to know that "Alice was the project lead until January, then Bob took over," Zep handles this natively.

When NOT to use Zep:

You don't need temporal reasoning — if facts in your domain don't change over time, the temporal knowledge graph adds complexity you won't use
You want to self-host Zep — Community Edition is deprecated. You can self-host using the open-source Graphiti library directly, but that's the graph engine without Zep's higher-level features
You need predictable costs — credit-based pricing requires careful usage estimation upfront

Getting started:

pip install graphiti-core
# Requires a graph database — Neo4j, FalkorDB, or Kuzu (embedded)

import asyncio
from datetime import datetime, timezone
from graphiti_core import Graphiti
from graphiti_core.nodes import EpisodeType

async def main():
graphiti = Graphiti("bolt://localhost:7687", "neo4j", "password")

# Add episodes — Graphiti extracts entities and relationships automatically
await graphiti.add_episode(
name="team-update-1",
episode_body="Alice is the project lead for the ML platform migration.",
source=EpisodeType.text,
source_description="team standup",
reference_time=datetime.now(timezone.utc),
)

# Search — results include temporal validity windows
results = await graphiti.search("Who leads the ML platform?")
for r in results:
print(f"Fact: {r.fact} | Valid from: {r.valid_at}")

await graphiti.close()

asyncio.run(main())

Pricing: Free (1K credits) · $25/mo Flex (20K credits) · Enterprise custom

5. Cognee

What it is: A knowledge graph + vector search memory framework with a focus on reducing hallucinations through structured extraction.

Memory class: Institutional. Built around knowledge graph extraction from structured and unstructured data sources. Less focused on conversation-level personalization, more on building domain knowledge from documents, images, and audio.

Architecture: Pipeline-based ingestion from 30+ data sources. Data flows through enrichment stages: chunking, embedding generation, and graph-based extraction that produces subject-relation-object triplets. The knowledge graph and vector index are built in parallel. Retrieval can combine time filters, graph traversal, and vector similarity in a single query. Runs on SQLite (relational), LanceDB (vector), and Kuzu (graph) by default — no external services required.

Strengths:

30+ data source connectors out of the box
Multimodal support (text, images, audio transcriptions)
Runs fully locally — no cloud dependency required
"Memory in 6 lines of code" — minimal setup for basic use
Graduated from GitHub's Secure Open Source program
Recently raised €7.5M (~$8.1M) seed funding

Weaknesses:

Python-only
Smaller community than Mem0 or Zep
Managed cloud offering is newer and less battle-tested
Documentation could be more comprehensive

Best for: Teams that want knowledge graph capabilities with multimodal data ingestion. Strong choice if you're pulling memories from diverse sources (documents, images, audio) and want structured extraction without building your own pipeline.

When NOT to use Cognee:

You need TypeScript or Go support — Cognee is Python-only
Your memory needs are primarily conversational personalization — Cognee is built for knowledge extraction from documents and data, not chat context
You need a battle-tested managed cloud — their cloud offering is newer and less proven than Mem0 or Zep

Getting started:

pip install cognee
export LLM_API_KEY="YOUR_API_KEY"

import cognee
import asyncio

async def main():
await cognee.add("Alice leads the ML platform migration. The project started in January.")
await cognee.cognify()  # Process and build the knowledge graph

results = await cognee.search("Who leads the ML platform?")
for result in results:
print(result)

asyncio.run(main())

Pricing: Free open source · Platform (€8.50/1M input tokens) · On-prem (€1,970/mo) · Enterprise custom

6. SuperMemory

What it is: An all-in-one memory API that bundles memory, RAG, user profiles, and connectors into a single service.

Memory class: Personalization + some institutional. Strong on user profiles, preference tracking, and conversation memory. Fact extraction, contradiction resolution, and knowledge graph features add institutional capabilities, though the product focuses heavily on user-facing memory and RAG workflows.

Architecture: Combines a memory graph, full RAG stack, and data connectors in one AI agent memory system. Built on Cloudflare Workers + PostgreSQL with pgvector. Ingestion handles embedding, chunking, fact extraction, and contradiction resolution internally. User profiles are automatically built and maintained from stored memories. Facts are split into static (long-term) and dynamic (recent context) categories. No separate vector DB configuration needed.

Strengths:

81.6% on LongMemEval (GPT-4o), with strong results on LoCoMo and ConvoMem as well
$3M raised (October 2025) — funded and actively developing
Simple API — "add memory with a single call"
Generous free tier (1M tokens processed, 10K search queries)
Automatic fact extraction, contradiction resolution, and stale information expiration
MCP server and plugins for Claude Code, OpenCode, and OpenClaw

Weaknesses:

Closed source — no open-source version available
Self-hosting requires an enterprise agreement
Smaller community than Mem0 or Letta
Relatively newer — less production track record

Best for: Teams that want the fastest path to memory + RAG without managing infrastructure. Especially appealing if you don't want to configure vector databases, embedding pipelines, or chunking strategies separately.

When NOT to use SuperMemory:

You need open-source or easy self-hosting — SuperMemory is closed source, and self-hosting requires an enterprise agreement
You need deep institutional knowledge capabilities — fact extraction and contradiction resolution are available, but the primary strength is user-facing memory and RAG
You want a large community for support — SuperMemory is newer with a smaller ecosystem than Mem0 or Letta

Getting started:

pip install supermemory
export SUPERMEMORY_API_KEY="YOUR_API_KEY"  # From console.supermemory.ai

from supermemory import Supermemory

client = Supermemory()

# Store a memory
client.add(
content="User prefers Python and works on ML infrastructure.",
container_tag="user_123",
)

# Retrieve profile + relevant memories in one call
result = client.profile(container_tag="user_123", q="programming preferences")
print(result.profile.static)   # Long-term facts
print(result.profile.dynamic)  # Recent context

Pricing: Free (1M tokens, 10K queries) · Pro/Scale with overage pricing · Startup program ($1K credits for 6 months)

7. LangMem (LangChain Memory)

What it is: An open-source memory library designed for LangGraph applications. Provides semantic, episodic, and procedural memory types.

Memory class: Personalization. Stores user preferences and conversation context as flat key-value items. No entity extraction, no knowledge graph, no structured fact extraction — limited ability to build institutional knowledge.

Architecture: Flat key-value items with vector search. Memories are stored as JSON documents in LangGraph's structured store, scoped by configurable namespaces (user, team, app route). A background memory manager can automatically extract and consolidate facts from conversations. Retrieval is single-strategy vector similarity only. No knowledge graph, no entity extraction, no relationship modeling.

Strengths:

Completely free (MIT license)
Deep integration with LangGraph's Long-term Memory Store
Full data ownership — you control the storage backend
Unique prompt optimization feature that refines agent behavior from conversation data
Background memory manager for automatic extraction and consolidation

Weaknesses:

Severe framework lock-in — has low-level primitives that work independently, but the primary value is tightly coupled to LangGraph
No knowledge graph or entity extraction
Python-only
No managed cloud offering as of early 2026 (a hosted memory service was announced in May 2025 but availability is unclear)
Development cadence has slowed — check the repo for recent activity before committing
Smallest community (~1.3K stars)

Best for: Teams already committed to LangGraph that want free, built-in memory. If you're not using LangGraph, look elsewhere.

When NOT to use LangMem:

You're not using LangGraph — the primary value is tightly coupled to the LangGraph ecosystem
You need knowledge graphs, entity extraction, or temporal reasoning — LangMem doesn't have them
You need a managed cloud option — there isn't one
Long-term maintenance matters — development cadence has slowed, so evaluate the repo's activity before committing

Getting started:

pip install langmem
export OPENAI_API_KEY="YOUR_API_KEY"

from langgraph.prebuilt import create_react_agent
from langgraph.store.memory import InMemoryStore
from langmem import create_manage_memory_tool, create_search_memory_tool

store = InMemoryStore(
index={"dims": 1536, "embed": "openai:text-embedding-3-small"}
)

agent = create_react_agent(
"anthropic:claude-3-5-sonnet-latest",
tools=[
create_manage_memory_tool(namespace=("memories",)),
create_search_memory_tool(namespace=("memories",)),
],
store=store,
)

# The agent decides what to store — just chat normally
agent.invoke({"messages": [{"role": "user", "content": "Remember that I prefer dark mode."}]})

response = agent.invoke({"messages": [{"role": "user", "content": "What are my preferences?"}]})
print(response["messages"][-1].content)

Pricing: Free (MIT)

8. LlamaIndex Memory

What it is: A set of composable memory modules built into the LlamaIndex agent framework. Not a standalone memory system — it's a component feature.

Memory class: Personalization. Conversation buffers and vector search over past messages. The memory modules don't include entity extraction, knowledge graphs, or temporal tracking — designed for session continuity, not accumulated domain expertise. LlamaIndex offers knowledge graph capabilities separately, but they aren't part of the memory system.

Architecture: Modular buffers that can be composed:

ChatMemoryBuffer — FIFO queue with configurable token limits
ChatSummaryMemoryBuffer — auto-summarizes when the buffer exceeds capacity
VectorMemory — stores and retrieves messages via vector search
SimpleComposableMemory — combines a primary buffer with secondary memory sources

Short-term memory is a FIFO queue of ChatMessage objects. When it exceeds the configurable token limit (default 30K), oldest messages are flushed to long-term storage. The newer Memory class adds pluggable memory blocks. These include FactExtractionMemoryBlock for LLM-powered fact extraction and VectorMemoryBlock for semantic search over past interactions.

Strengths:

Part of a massive, mature ecosystem (~48K stars for the full framework)
Composable and flexible — build the memory behavior you need from primitives
Well-documented
Summary memory and vector memory built in
Free and open source

Weaknesses:

Not a standalone memory solution — tied to LlamaIndex
The memory modules themselves don't include knowledge graph or entity extraction (though LlamaIndex offers these capabilities separately)
No temporal tracking
Simpler than dedicated memory frameworks
Less sophisticated than Mem0/Zep/Hindsight/Letta for complex memory needs

Best for: Teams already using LlamaIndex for RAG or agents that need basic conversation persistence. If you need something more than buffer management, look at dedicated memory frameworks.

When NOT to use LlamaIndex Memory:

You're not already in the LlamaIndex ecosystem — adopting LlamaIndex just for memory modules doesn't make sense
You need institutional knowledge capabilities — the memory modules are conversation buffers, not knowledge extraction engines (LlamaIndex has separate KG capabilities, but they aren't integrated into the memory system)
You need a standalone memory service — this is a component feature, not a product

Getting started:

pip install llama-index-core llama-index-llms-openai
export OPENAI_API_KEY="YOUR_API_KEY"

from llama_index.core.memory import Memory
from llama_index.core.agent.workflow import FunctionAgent
from llama_index.llms.openai import OpenAI

memory = Memory.from_defaults(session_id="my_session", token_limit=40000)
agent = FunctionAgent(llm=OpenAI(model="gpt-4o-mini"), tools=[])

# Memory persists across calls within the same session
response = await agent.run("My name is Alice and I work on ML infrastructure.", memory=memory)
response = await agent.run("What do I work on?", memory=memory)

Pricing: Free (open source) · LlamaCloud available for managed infrastructure

AI Agent Memory Pitfalls & Edge Cases

Benchmarks don't test what matters most — yet. This deserves more than a passing mention. The entire premise of this article is that agents need to accumulate operational knowledge. But no widely adopted benchmark actually tests that.

LoCoMo and LongMemEval are the de facto standards. Multiple providers — Hindsight, SuperMemory, Mem0 — all cite strong scores on these tests. But both benchmarks evaluate the same thing: can the system retrieve facts from long conversational histories? That's useful, but it only covers the personalization problem.

What neither benchmark tests:

Does the agent make fewer errors on run 10 than run 1?
Can it learn domain-specific edge cases from corrections?
Does accumulated memory actually improve task outcomes (procurement accuracy, code review quality, research depth)?
How does retrieval quality degrade as the memory bank grows to 100K+ facts?

These are the questions that matter for institutional knowledge — the harder problem this article focuses on. Until benchmarks catch up, treat published scores as a necessary-but-not-sufficient signal. They tell you the retrieval engine works on conversational data. They don't tell you whether it will help your agent get better at its job.

What to do: Use benchmark scores to shortlist frameworks, then run your own evaluation against your actual workload. Store real task data, run the agent repeatedly, and measure whether outcomes improve over time. That's the test that matters.

"Memory" means different things. A ChatMemoryBuffer that truncates old messages is not the same as a knowledge graph that tracks entity relationships over time. Make sure the framework you pick matches your actual requirements — not just the marketing label.

Framework lock-in is real. LangMem is primarily designed for LangGraph and offers limited value outside it. LlamaIndex Memory is tied to LlamaIndex. If there's any chance you'll switch frameworks, pick a standalone memory system (Mem0, Zep, Hindsight, Cognee, or SuperMemory).

Self-hosted doesn't always mean open source. SuperMemory is closed source — self-hosting requires an enterprise agreement. Some other frameworks are open core with advanced features gated behind commercial tiers. Always verify what's actually available under the license you're willing to use.

Graph features are often paywalled. Mem0's graph capabilities require the $249/mo Pro tier. Zep's advanced features are cloud-only. If knowledge graph is your primary requirement, verify what's actually available on the tier you're willing to pay for.

Retrieval strategy matters more than storage. Most frameworks can store memories. The difference is in how they retrieve them. Pure vector search can struggle when the query uses different terminology than the stored memory. Multi-strategy retrieval (semantic + keyword + graph + temporal) is more robust but adds complexity and latency.

How to Choose the Right AI Agent Memory Framework

Start with the memory class question — it narrows the field fast:

If your agent needs to...	Memory class	Frameworks to evaluate
Remember user preferences and conversation history	Personalization	Any — all 8 handle this
Learn from experience and compound domain knowledge	Institutional	Hindsight, Letta, Zep, Cognee (Mem0 and SuperMemory partially)
Do both, with institutional knowledge as the priority	Both	Hindsight, Letta, Zep

Then narrow by your specific requirements:

If you need...	Consider
Agents that learn from experience, highest benchmark scores	Hindsight — built for institutional knowledge, fact extraction + synthesis + multi-strategy retrieval
Largest ecosystem and community	Mem0 — 49K stars, most integrations, proven managed service
Agents that manage their own context	Letta — OS-inspired tiers, agents self-edit memory blocks
Temporal entity tracking	Zep / Graphiti — facts have validity windows, peer-reviewed architecture
Knowledge graph + multimodal ingestion	Cognee — 30+ connectors, graph extraction, runs locally
Simplest API, zero infra	SuperMemory — one call to store, built-in RAG, no vector DB config
Free + already using LangGraph	LangMem — MIT, deep LangGraph integration, but locked in
Already using LlamaIndex	LlamaIndex Memory — composable buffers, well-integrated, but basic

There's also a higher-level architectural decision:

Vector-first (LangMem, SuperMemory) — similarity-based retrieval, simpler to reason about. Primarily solves personalization.
Tiered / agent-managed (Letta) — OS-inspired memory hierarchy where agents control their own context, deciding what stays in working memory versus long-term storage.
Vector + Graph (Mem0, Zep, Cognee) — entity relationships and structured knowledge, with varying emphasis on temporal reasoning. Mem0 gates graph features behind Pro. Zep and Cognee lead with graphs.
Multi-strategy retrieval (Hindsight) — four parallel retrieval strategies (semantic, BM25, graph traversal, temporal) with cross-encoder reranking. This approach catches what single-strategy AI agent memory systems miss.

If you're unsure, lean toward a framework that solves institutional knowledge. You'll get personalization for free, and you won't need to re-platform when your agents move from answering questions to doing work.

Recap: Choosing the Best AI Agent Memory System

We started with two distinct problems: personalization (remembering who the user is) and institutional knowledge (learning how to do the job better over time). Most AI agent memory frameworks were built for the first problem. Fewer solve the second.

If your agent only needs to recall user preferences and conversation history, many of the frameworks here will work. But if you're building agents that do real, repeated work — procurement, research, operations, code review — the personalization problem is just the starting point. The harder and more valuable problem is institutional knowledge. Can your agent extract lessons from experience, compound them across runs, and get measurably better at its job?

The AI agent memory frameworks most focused on institutional knowledge today — Hindsight, Letta, Zep, and Cognee — also handle personalization. Mem0 and SuperMemory have institutional capabilities too (graph features, fact extraction), though their primary strength is personalization. The reverse path is harder. A conversation buffer or flat vector store rarely evolves into a full knowledge extraction system without significant additional infrastructure.

Pick an AI agent memory framework that solves the harder problem. You'll get personalization for free, and you won't have to re-platform when your agents move from answering questions to doing work.
Next Steps
Run your own evaluation. Pick 2–3 AI agent memory frameworks and test them with your actual data. Benchmark results are a strong starting signal, but your use case has its own data shape and query patterns.
If you're evaluating institutional memory systems, start by testing Hindsight alongside Letta or Zep. All three take very different architectural approaches. Running them against your own data will quickly reveal which model fits your workload best.
Watch for agent-task benchmarks. LoCoMo and LongMemEval are the current standard, but they only test conversational memory. The next wave of benchmarks will evaluate whether AI agent memory helps agents perform tasks better over time — fewer errors, faster ramp-up, and learned edge cases.
Consider your lock-in tolerance. If you might switch agent frameworks, avoid memory systems coupled to a specific ecosystem.
Read the pricing fine print. Free tiers are generous, but graph features, compliance certs, and production SLAs often require paid plans. Budget accordingly.
See Hindsight in action

Give your AI agents persistent memory that learns and improves with use. Book a 30-minute walkthrough and we'll show you how Hindsight fits your stack — cloud or self-hosted.

Book a demo of Hindsight
View on GitHub
Further Reading
What Is Agent Memory? — foundational concepts behind persistent AI memory
How Do AI Agents Learn? — the four mechanisms behind agent improvement, and where memory fits relative to fine-tuning, in-context learning, and skills
Do AI Agents Learn Between Sessions? — the honest answer for why a fresh chat starts from zero by default
Fine-Tuning vs Memory for AI Agents — head-to-head decision guide on which mechanism fits which problem
Why Fine-Tuning Is Almost Never the Right Answer — the opinionated case for why memory should be the default
Agent Memory vs RAG — how memory differs from retrieval-augmented generation
Hindsight vs Mem0 — head-to-head on auto-consolidation vs log-style memory
Claude Code memory: complete guide — the complete explainer for Claude Code's native memory and its limits
Claude Code cross-project memory — native patterns and the multi-scope answer
Claude Code memory vs Mem0 vs Hindsight — backend comparison for Claude Code users
AI Memory Poisoning — the persistent attack vector against agent memory (OWASP ASI06)
How to Prevent AI Memory Poisoning — the five-layer defense playbook
Memory Poisoning vs Prompt Injection — why session-level controls don't catch persistent attacks
OWASP ASI06: Memory and Context Poisoning Explained — the standards-aligned classification
OWASP Agent Memory Guard vs Hindsight Memory Defense — two ASI06 implementations compared
