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

For this milestone we will be focusing only on the low-level llm driver, not the llm_provider.

## Implementation Steps

### A1 [x] Defin LLM Driver behavior/protocol with clear specifications
This has been done in nova/llm/driver.ex.

### A2 [ ] Create a mock llm for use in unit tests and other tests.
This will have a couple of key capabilities.  By default, it will
generate a response that is based on the last row of dialog
fed into it.  So if the last row of text in the dialog is "x"
then it will return "f(x)".  This makes unit tests easy to read and reason about.

In addition, it will have the capability to store the next response that is desired,
which can be fed to it by a unit test.


### A3. [ ] Create a concrete implementation for at least one LLM service (e.g., OpenAI)

### A4. [ ] Implement the LLM Provider with core cross-cutting capabilities
