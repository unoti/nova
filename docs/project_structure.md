# Nova Project Structure

This document describes the organization of Nova's codebase and explains the rationale behind our approach to structuring the project.

## Directory Structure

```
nova/
├── lib/
│   ├── nova.ex                 # Application entry point
│   └── nova/
│       ├── core/               # Core business logic 
│       ├── dialog/             # Dialog-specific modules
│       │   └── ...
│       ├── entities/           # Domain models
|             └── dialog.ex     # Dialog management: chat history
│       ├── 
│       └── llm/                # LLM provider integrations
│           └── driver.ex       # LLM driver, lowest level behavior
│
├── test/                       # Tests mirror the lib structure
│   └── nova/
│       └── ...
│
└── docs/                       # Documentation
│   └── project_structure.md    # This file
│   └── features/               # Detailed design specs as we work on features
```

## Philosophy & Rationale

Our approach to organizing the codebase is guided by a few key principles:

### Entities vs. Core

We've chosen to separate our codebase to include two primary concerns:

1. **Entities** (`lib/nova/entities/`):
   - Contains domain models that represent the fundamental data structures in our application
   - These are the "nouns" of our system
   - Files in this directory have minimal dependencies on other parts of the system
   - This is similar to the "models" directory in Python applications but emphasizes that these represent domain entities regardless of persistence mechanism
   - Entities will eventually be persisted in blob storage or CosmosDB, not in a traditional relational database

2. **Core** (`lib/nova/core/`):
   - Contains the essential business logic and algorithms
   - These are the "verbs" of our system - the operations that work on our entities
   - Files here implement the actual functionality of the application

This separation provides several benefits:
- Clear distinction between data (entities) and operations (core)
- Better dependency management (entities have fewer dependencies)
- Improved testability
- More intuitive organization for newcomers to the codebase

### Existing Structure

The project already includes:

- **dialog/** - Contains modules related to dialog management
- **llm/** - Contains integrations with various LLM providers

These represent feature-specific modules organized by domain function, which complements our entities/core approach.

### Avoiding "Utils"

We've intentionally avoided creating a "utils" directory. Our philosophy is that every piece of code should have a clear purpose and home in the application structure. If code is genuinely useful, it belongs somewhere specific based on its domain function rather than in a catch-all utilities directory.

### Test Mirroring

Our test structure mirrors the lib structure. For every module in the application, there's a corresponding test file in the same relative location within the test directory. This makes it easy to find tests for any given module and reinforces the organization of the codebase.

## Future Considerations

As the project grows, we may introduce additional directories:

- **Contexts**: If we identify bounded contexts in our domain, we might introduce context-specific directories.
- **Services**: For integrations with external services or APIs.
- **Protocols**: For defining behavior interfaces that can have multiple implementations.

However, we'll be careful to maintain the clarity of our structure and ensure that new directories serve a clear purpose in the application architecture.
