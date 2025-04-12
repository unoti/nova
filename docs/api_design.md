# Nova: API Design Principles

This document outlines the key principles and patterns that guide Nova's API design, ensuring a consistent and intuitive developer experience.

## Core Design Values

### 1. Explicit Over Implicit

Nova prefers explicit configuration and behavior over "magic" or implicit conventions. This makes code using Nova more readable and predictable.

```elixir
# Good: Explicitly configure the model
conversation = Nova.Conversation.new(model: "gpt-4")

# Avoid: Relying on implicit global configuration
conversation = Nova.Conversation.new()  # Where is the model configured?
```

### 2. Progressive Disclosure

Nova's API should be approachable for beginners while offering depth for advanced users. We achieve this through progressive disclosure:

```elixir
# Simple case - sensible defaults
Nova.generate("Tell me about Elixir")

# More advanced - explicit options
Nova.generate("Tell me about Elixir",
  model: "gpt-4",
  temperature: 0.7,
  max_tokens: 500
)

# Expert level - full customization
Nova.generate("Tell me about Elixir",
  model: MyCustomModel,
  adapter: MyAdapter,
  callbacks: [MyCallback],
  retry_strategy: MyRetryStrategy
)
```

### 3. Pipeline-Friendly

Nova embraces Elixir's pipe operator (`|>`) to enable expressive, readable code:

```elixir
"Tell me about Elixir"
|> Nova.generate(model: "gpt-4")
|> Nova.extract_key_points()
|> Nova.format_as_markdown()
```

### 4. Composable Abstractions

Nova provides composable building blocks rather than monolithic frameworks:

```elixir
defmodule MyWorkflow do
  alias Nova.{Conversation, Agent, Tool}
  
  def run(query) do
    tools = [
      Tool.web_search(),
      Tool.calculator()
    ]
    
    agent = Agent.new(
      model: "gpt-4",
      tools: tools,
      persona: my_agent_persona()
    )
    
    Conversation.new()
    |> Conversation.add_message(:user, query)
    |> Agent.process(agent)
    |> Conversation.last_message()
  end
end
```

### 5. Functional Core, OTP Shell

Nova uses functional programming for data transformations and OTP for stateful operations:

```elixir
# Functional core - pure functions for data manipulation
defmodule Nova.Prompt do
  def render(template, vars) do
    # Pure function to render template with variables
  end
end

# OTP shell - for stateful operations
defmodule Nova.Conversation do
  use GenServer
  
  # State management via OTP
end
```

## API Patterns

### Configuration

Nova uses a consistent approach to configuration:

1. **Application Environment**: Global defaults
2. **Runtime Configuration**: Per-component settings
3. **Operation Options**: Per-operation overrides

```elixir
# In config.exs - global defaults
config :nova,
  default_model: "gpt-4",
  api_key: {:system, "OPENAI_API_KEY"}

# Component configuration - per component settings
agent = Nova.Agent.new(
  model: "claude-3-opus"
)

# Operation options - per operation overrides
response = agent |> Nova.Agent.generate("Query", temperature: 0.8)
```

### Error Handling

Nova follows Elixir conventions for error handling:

```elixir
# Functions that can fail return tagged tuples
{:ok, result} = Nova.generate("Query")
{:error, reason} = Nova.generate("Bad query with invalid settings")

# Or raise versions for pipeline-friendly usage
result = Nova.generate!("Query")

# With detailed error types
case Nova.generate("Query") do
  {:ok, result} -> 
    # Handle success
  {:error, %Nova.Error.RateLimited{retry_after: seconds}} -> 
    # Handle rate limiting
  {:error, %Nova.Error.InvalidPrompt{reason: reason}} ->
    # Handle prompt errors
end
```

### Callbacks and Hooks

Nova provides a consistent callback system:

```elixir
Nova.generate("Tell me about Elixir",
  on_token: fn token -> IO.write(token) end,
  on_complete: fn result -> send(self(), {:complete, result}) end,
  on_error: fn error -> Logger.error("Generation failed: #{inspect(error)}") end
)
```

### Streaming

Nova embraces Elixir's Stream for working with streaming responses:

```elixir
Nova.stream("Generate a long story")
|> Stream.each(&IO.write/1)
|> Stream.run()

# Or with transformations
Nova.stream("Generate JSON data")
|> Stream.flat_map(&Jason.decode!/1)
|> Stream.filter(fn item -> item.score > 0.5 end)
|> Enum.to_list()
```

## Module Organization

Nova organizes its API into focused modules with clear responsibilities:

```
Nova                   # Main namespace
├── Model              # LLM interface
│   ├── OpenAI         # Provider-specific implementations
│   ├── Anthropic
│   └── ...
├── Conversation       # Conversation management
├── Agent              # Agent definition and behavior
├── Tool               # Tool definitions for agents
├── Memory             # Memory mechanisms
├── Prompt             # Prompt construction and templating
├── Workflow           # Multi-agent workflow orchestration
└── Telemetry          # Observability hooks
```

## Naming Conventions

Nova follows consistent naming across its API:

- **Verbs for actions**: `generate`, `stream`, `extract`, `process`
- **Nouns for entities**: `Agent`, `Conversation`, `Tool`
- **Adjectives for variations**: `SimpleMemory`, `AdvancedRouter`

## Versioning and Stability

Nova follows semantic versioning and clearly documents API stability:

- **Stable**: Production-ready APIs with backward compatibility guarantees
- **Beta**: APIs that are stabilizing but may still change
- **Experimental**: APIs that are likely to change significantly

Each module and function includes stability annotations:

```elixir
@doc """
Generates a response from the language model.

Status: Stable
Since: 0.1.0
"""
@spec generate(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
def generate(prompt, options \\ []) do
  # Implementation
end
```
