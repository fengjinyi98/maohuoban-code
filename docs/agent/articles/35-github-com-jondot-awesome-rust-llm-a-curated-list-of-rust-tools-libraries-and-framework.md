# jondot/awesome-rust-llm: 🦀 A curated list of Rust tools, libraries, and frameworks for working with LLMs, GPT, AI

- 来源链接：https://github.com/jondot/awesome-rust-llm
- 浏览器最终地址：https://github.com/jondot/awesome-rust-llm
- 原始收集：docs/agent/4.md:15
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：🦀 A curated list of Rust tools, libraries, and frameworks for working with LLMs, GPT, AI - jondot/awesome-rust-llm

---

## 原始备注

https://github.com/jondot/awesome-rust-llm

## 正文

awesome-rust-llm
Public
Watch
Fork 33
Star 579
jondot/awesome-rust-llm
 master
1 Branch
0 Tags
t
T
Add file
Add file
Code
Folders and files
Name	Last commit message	Last commit date

Latest commit
jondot
Update README.md
e8e8ba2
 · 
History
8 Commits

README.md

Update README.md

Repository files navigation
README

__       __ __          
.---.-.--.--.--.-----.-----.-----.--------.-----.___.----.--.--.-----|  |_ ___|  |  .--------.
|  _  |  |  |  |  -__|__ --|  _  |        |  -__|___|   _|  |  |__ --|   _|___|  |  |        |
|___._|________|_____|_____|_____|__|__|__|_____|   |__| |_____|_____|____|   |__|__|__|__|__|

https://github.com/jondot/awesome-rust-llm

Awesome Rust LLM is an awesome style list that keeps track and curates the best Rust based LLM frameworks, libraries, tools, tutorials, articles and more. PRs are welcome!

Models & Inference
llm - a Rust library for running inference from a number of supported LLMs, loads ggml based models
rust-bert - all in one pipelines for for transformer-based models (BERT, DistilBERT, GPT2,...). Good for local embedding, port of transformers (python)
llm-chain - chaining LLMs in Rust
smartgpt (how it works)- use LLMs with the ability to complete complex tasks using plugins
diffusers - Stable Diffusion using Rust, 45% faster than Pytorch
postgresml - an amazing Postgres extension to do model fetching, inference all with SQL as part of your Postgres instance
Projects

aichat - a pure Rust CLI implementing AI chat, with advanced features such as real-time streaming, text highlighting and more

browser-agent - a headless browser driven by GPT-4. Sends off a simplified page representation and receives & executes instructions from GPT using a custom message format

tenere - TUI interface for LLMs

How it works? here's a prompt snippet:

You must respond with ONLY one of the following commands AND NOTHING ELSE:
- CLICK X - click on a given element. You can only click on links, buttons, and inputs!
- TYPE X \"TEXT\" - type the specified text into the input with id X and press ENTER
- ANSWER \"TEXT\" - Respond to the user with the specified text once you have completed the objective

ajeto - LLM personal assistant
shortgpt - Ask shortgpt for instant and concise answers
autorust - macros that generate AI driven rust code in compile time
clerk - LLM based file organizer
gptcommit - prepare commit message with GPT
LLM Memory
indexify - A retrieval and long term memory service for LLMs
memex - Super-simple, fully Rust powered "memory" (doc store + semantic search) for LLM projects, semantic search, etc.
motorhead - a memory and information retrieval server for LLMs.
Uses Redis as vector store for long term memory,
Works with OpenAI API
js example, python example
Core Libraries

tiktoken - tiktoken is a Python library with a Rust core implementing a fast BPE tokeniser for use with OpenAI's models

BPE is done in Rust
Made by OpenAI

tiktoken-rs - a Rust focused library based on the tiktoken core with additional enhancements for use in Rust code. (Pyton parts in tiktoken done in pure Rust)

// Rust
use tiktoken_rs::p50k_base;

let bpe = p50k_base().unwrap();
let tokens = bpe.encode_with_special_tokens(
"This is a sentence   with spaces"
);
println!("Token count: {}", tokens.len());

polars - a faster, pure Rust pandas alternative

rllama - a pure Rust implemenation of LLaMa inference. Great for embedding into other apps or wrapping for a scripting language.

whatlang - Rust library using a multiclass logistic regression model to detect languages

OpenAI API - a strongly typed Rust client for the OpenAI API

Tools
spider - crawler / spider written in Rust for when you need a whole-website dump. Unlike Scrapy, focuses on dumping data but the post-processing is done later.
Services
dust - a full service for workflow running with composable blocks. Core is in Rust, various frontends in Typescript.
Vector Stores
pgvecto.rs - Vector database plugin for Postgres, written in Rust, specifically designed for LLM. 20x faster than pgvector
qdrant - Qdrant - Vector Database for the next generation of AI applications
About

🦀 A curated list of Rust tools, libraries, and frameworks for working with LLMs, GPT, AI

Topics
rust ai rust-lang gpt llm
Resources
Readme
Activity
Stars
579 stars
Watchers
11 watching
Forks
33 forks
Report repository

Contributors
1
jondot Dotan J. Nahum
