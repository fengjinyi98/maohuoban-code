# ReAct vs Plan-and-Execute: A Practical Comparison of LLM Agent Patterns - DEV Community

- 来源链接：https://dev.to/jamesli/react-vs-plan-and-execute-a-practical-comparison-of-llm-agent-patterns-4gh9
- 浏览器最终地址：https://dev.to/jamesli/react-vs-plan-and-execute-a-practical-comparison-of-llm-agent-patterns-4gh9
- 原始收集：docs/agent/3.md:20
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：When building LLM Agent systems, choosing the right reasoning pattern is crucial. This article... Tagged with llm, ai, langchain, agents.

---

## 原始备注

https://dev.to/jamesli/react-vs-plan-and-execute-a-practical-comparison-of-llm-agent-patterns-4gh9

## 正文

James Lee

Posted on Nov 18, 2024

ReAct vs Plan-and-Execute: A Practical Comparison of LLM Agent Patterns
#
agents
#
ai
#
langchain
#
llm
Enterprise LLM Agent Systems Engineering (7 Part Series)
1
ReAct vs Plan-and-Execute: A Practical Comparison of LLM Agent Patterns
2
OpenAI Assistants API Enterprise Application Guide
...
3 more parts...
6
LangGraph State Machines: Managing Complex Agent Task Flows in Production
7
Agent Task Orchestration System: From Design to Production

When building LLM Agent systems, choosing the right reasoning pattern is crucial. This article provides an in-depth comparison of two mainstream Agent reasoning patterns: ReAct (Reasoning and Acting) and Plan-and-Execute, helping you make informed technical decisions through practical cases.

Key Takeaways

Understanding Two Major Agent Patterns

ReAct's reasoning-action loop mechanism
Plan-and-Execute's planning-execution separation strategy

LangChain-based Implementation

ReAct pattern code implementation and best practices
Plan-and-Execute pattern engineering solutions

Performance and Cost Analysis

Quantitative analysis of response time and accuracy
Detailed calculation of token consumption and API costs

Practical Cases and Applications

Real-world data analysis tasks
Optimal pattern selection for different scenarios

Systematic Selection Methodology

Scene characteristics and pattern matching guidelines
Hybrid strategy implementation recommendations
1. Working Principles of Both Patterns
1.1 ReAct Pattern

ReAct (Reasoning and Acting) pattern is an iterative approach that alternates between thinking and acting. Its core workflow includes:

Reasoning: Analyze current state and objectives
Acting: Execute specific operations
Observation: Obtain action results
Iteration: Continue thinking and acting based on observations

Typical ReAct Prompt Template:

REACT_PROMPT = """Answer the following questions as best you can. You have access to the following tools:

{tools}

Use the following format:

Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Question: {input}
Thought: {agent_scratchpad}"""

1.2 Plan-and-Execute Pattern

Plan-and-Execute pattern adopts a "plan first, execute later" strategy, dividing tasks into two distinct phases:

Planning Phase:

Analyze task objectives
Break down into subtasks
Develop execution plan

Execution Phase:

Execute subtasks in sequence
Process execution results
Adjust plan if needed

Typical Plan-and-Execute Prompt Template:

PLANNER_PROMPT = """You are a task planning assistant. Given a task, create a detailed plan.

Task: {input}

Create a plan with the following format:
1. First step
2. Second step
...

Plan:"""

EXECUTOR_PROMPT = """You are a task executor. Follow the plan and execute each step using available tools:

{tools}

Plan:
{plan}

Current step: {current_step}
Previous results: {previous_results}

Use the following format:
Thought: think about the current step
Action: the action to take
Action Input: the input for the action"""

2. Implementation Comparison
2.1 ReAct Implementation with LangChain
from langchain.agents import initialize_agent, Tool
from langchain.agents import AgentType
from langchain.chat_models import ChatOpenAI

def create_react_agent(tools, llm):
return initialize_agent(
tools=tools,
llm=llm,
agent=AgentType.CHAT_CONVERSATIONAL_REACT_DESCRIPTION,
verbose=True
)

# Usage example
llm = ChatOpenAI(temperature=0)
tools = [
Tool(
name="Search",
func=search_tool,
description="Useful for searching information"
),
Tool(
name="Calculator",
func=calculator_tool,
description="Useful for doing calculations"
)
]

agent = create_react_agent(tools, llm)
result = agent.run("What is the population of China multiplied by 2?")

2.2 Plan-and-Execute Implementation with LangChain
from langchain.agents import PlanAndExecute
from langchain.chat_models import ChatOpenAI

def create_plan_and_execute_agent(tools, llm):
return PlanAndExecute(
planner=create_planner(llm),
executor=create_executor(llm, tools),
verbose=True
)

# Usage example
llm = ChatOpenAI(temperature=0)
agent = create_plan_and_execute_agent(tools, llm)
result = agent.run("What is the population of China multiplied by 2?")

3. Performance and Cost Analysis
3.1 Performance Comparison
Metric	ReAct	Plan-and-Execute
Response Time	Faster	Slower
Token Consumption	Medium	Higher
Task Completion Accuracy	85%	92%
Complex Task Handling	Medium	Strong
3.2 Cost Analysis

Using GPT-4 model for complex tasks:

Cost Item	ReAct	Plan-and-Execute
Average Token Usage	2000-3000	3000-4500
API Calls	3-5 times	5-8 times
Cost per Task	$0.06-0.09	$0.09-0.14
4. Case Study: Data Analysis Task

Let's compare both patterns through a practical data analysis task:

Task Objective: Analyze a CSV file, calculate sales statistics, and generate a report.

4.1 ReAct Implementation
from langchain.agents import create_csv_agent
from langchain.chat_models import ChatOpenAI

def analyze_with_react():
agent = create_csv_agent(
ChatOpenAI(temperature=0),
'sales_data.csv',
verbose=True
)

return agent.run("""
1. Calculate the total sales
2. Find the best performing product
3. Generate a summary report
""")

4.2 Plan-and-Execute Implementation
from langchain.agents import PlanAndExecute
from langchain.tools import PythonAstREPLTool

def analyze_with_plan_execute():
agent = create_plan_and_execute_agent(
llm=ChatOpenAI(temperature=0),
tools=[
PythonAstREPLTool(),
CSVTool('sales_data.csv')
]
)

return agent.run("""
1. Calculate the total sales
2. Find the best performing product
3. Generate a summary report
""")

5. Selection Guide and Best Practices
5.1 When to Choose ReAct

Simple Direct Tasks

Single clear objective
Few steps
Quick response needed

Real-time Interactive Scenarios

Customer service dialogues
Instant queries
Simple calculations

Cost-Sensitive Scenarios

Limited token budget
Need to control API calls
5.2 When to Choose Plan-and-Execute

Complex Multi-step Tasks

Requires task breakdown
Step dependencies
Intermediate result validation

High-Accuracy Scenarios

Financial analysis
Data processing
Report generation

Long-term Planning Tasks

Project planning
Research analysis
Strategic decisions
5.3 Best Practice Recommendations

Hybrid Usage Strategy

Choose patterns based on subtask complexity
Combine both patterns in one system

Performance Optimization Tips

Implement caching mechanisms
Enable parallel processing
Optimize prompt templates

Cost Control Methods

Set token limits
Implement task interruption
Use result caching
Conclusion

Both ReAct and Plan-and-Execute have their strengths, and the choice between them should consider task characteristics, performance requirements, and cost constraints. In practical applications, you can flexibly choose or even combine both patterns to achieve optimal results.

Enterprise LLM Agent Systems Engineering (7 Part Series)
1
ReAct vs Plan-and-Execute: A Practical Comparison of LLM Agent Patterns
2
OpenAI Assistants API Enterprise Application Guide
...
3 more parts...
6
LangGraph State Machines: Managing Complex Agent Task Flows in Production
7
Agent Task Orchestration System: From Design to Production
Top comments (0)
Subscribe
Code of Conduct • Report abuse
