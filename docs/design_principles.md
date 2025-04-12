# Nova: Guiding Principles

This document outlines the core principles that guide the development of Nova, an Elixir library for integrating AI into business workflows.

## Separation of Business Logic from Infrastructure Code

Business logic should be clearly visible and separate from infrastructure concerns. This means:

- Domain experts should be able to read and understand business logic without getting lost in technical details
- Changes to business rules should not require changes to infrastructure code, and vice versa
- Core business workflows should be expressed in a way that closely resembles the mental model of the domain

Our code should have sections where the business problem "shines through strongly," making it accessible to subject matter experts and business stakeholders.

## Building Abstractions That Make Complex Problems Simple

We continuously ask: "If I had something that would make this easy, what would it look like?"

This principle involves:
- Creating abstractions that align with the mental model of the problem domain
- Building domain-specific vocabularies and operations that make expressing solutions almost trivial
- Layering abstractions so each level appears simple while hiding complexity underneath
- Ensuring that business logic reads almost like plain English statements

The result should be deceptively simple-looking code that hides tremendous sophistication underneath.

## Loose Coupling and Composability

Components should be loosely coupled and highly composable, providing architectural flexibility beyond just testability:

- Define contracts/interfaces for key services (e.g., blob storage, LLM drivers)
- Implement multiple versions of each contract for different contexts (production, testing, development)
- Enable components to be combined in various ways to solve different problems
- Allow rapid assembly of complete systems from individual components

This approach creates a flexible architecture where components can be swapped without changing business logic.

## AI-Specific Layered Design

For AI components specifically, we implement a layered design that separates core functionality from enhanced features:

- **LLM Drivers**: Lean, focused interfaces to specific LLM implementations
  - Minimal contracts to make integration with new LLMs straightforward
  - Implementation-specific details isolated here

- **LLM Providers**: Higher-level components that use LLM Drivers and add:
  - Cross-cutting capabilities (events, metrics, plugins)
  - Common functionality shared across all LLM implementations
  - Enhanced features that all drivers can benefit from

This pattern ensures that implementing a new LLM Driver automatically grants access to all the enhanced features of the Provider layer.

## Collaborative Development

Development of Nova is a collaborative process that:
- Emphasizes learning and creating together
- Values knowledge sharing and open communication
- Ensures the system is built through teamwork rather than in isolation
- Keeps stakeholders at the center of decision-making

The best solutions emerge when everyone contributes their expertise to the project.