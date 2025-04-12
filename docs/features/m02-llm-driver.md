# Milestone 2: LLM Driver and Provider

## Overview

This milestone focuses on creating the core abstractions for interacting with Language Learning Models (LLMs) in Nova. The design follows our guiding principles of separation of concerns and loose coupling, with a two-tiered approach:

1. **LLM Driver**: A lean, minimal interface for direct communication with LLM services
2. **LLM Provider**: A higher-level abstraction that adds additional capabilities on top of any LLM Driver

## LLM Driver

### Purpose

The LLM Driver is designed to be as lean and small as practical. Its sole responsibility is to provide a simple, consistent interface for communicating with different LLM implementations (whether external API services or local models).

### Design Principles

- **Minimal Interface**: Focus only on core LLM operations
- **Easy Integration**: Make it straightforward to add support for new LLM services
- **Implementation Isolation**: Keep service-specific details contained within the driver
- **No Cross-Cutting Concerns**: The driver should not handle logging, metrics, or other auxiliary concerns

### Core Functionality

The LLM Driver should support:

- Basic completion requests
- Chat-based interactions
- Model-specific parameters
- Error handling specific to the underlying LLM service
- Consistent response formatting

## LLM Provider

### Purpose

The LLM Provider builds on top of an LLM Driver, adding cross-cutting capabilities and additional features that are useful across all LLM implementations.

### Design Principles

- **Enhanced Capabilities**: Add features beyond basic LLM interaction
- **Consistent Interface**: Present the same interface regardless of the underlying driver
- **Separation of Concerns**: Handle auxiliary functionality so drivers can remain focused
- **Pluggable Architecture**: Allow features to be added or removed as needed

### Core Functionality

The LLM Provider should add:

- **Event Emission**: Publish events for request/response lifecycle
- **Metrics Collection**: Track response times, token usage, costs, etc.
- **Plugin System**: Enable extension points for additional processing
- **Caching**: Optional caching of responses for identical requests
- **Rate Limiting**: Protect against overuse of LLM services
- **Fallback Mechanisms**: Gracefully handle service outages
- **Context Management**: Help manage conversation context and history

## Benefits of the Two-Tiered Approach

This separation provides several advantages:

1. **Simplified Integration**: Adding support for a new LLM only requires implementing the lean Driver interface
2. **Automatic Feature Inheritance**: New Drivers immediately gain all Provider capabilities
3. **Feature Consistency**: All LLM interactions benefit from the same enhanced features
4. **Focused Development**: Driver implementers can focus solely on the LLM-specific details
5. **Testing Flexibility**: Drivers can be tested in isolation from Provider features

## Implementation Strategy

1. Define the LLM Driver behavior/protocol with clear specifications
2. Create a concrete implementation for at least one LLM service (e.g., OpenAI)
3. Implement the LLM Provider with core cross-cutting capabilities
4. Build a simple testing implementation of the Driver for development
5. Add additional Driver implementations as needed

## Usage Example

```elixir
# Configuration (typically in application config)
config :nova, :llm,
  provider: Nova.LLM.Provider,
  driver: Nova.LLM.Driver.OpenAI,
  driver_options: [api_key: System.get_env("OPENAI_API_KEY")]

# Simple usage
{:ok, response} = Nova.LLM.complete("Explain quantum computing in simple terms")

# Chat conversation
{:ok, response} = Nova.LLM.chat([
  %{role: "system", content: "You are a helpful assistant."},
  %{role: "user", content: "What is the capital of France?"}
])

# With a specific driver
{:ok, response} = Nova.LLM.Provider.with_driver(Nova.LLM.Driver.Anthropic, fn driver ->
  Nova.LLM.chat(driver, messages, model: "claude-3-opus-20240229")
end)
```

This milestone establishes the foundation for all LLM interactions in Nova, enabling subsequent features to build on these core abstractions.