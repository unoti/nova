# Nova

An Elixir library for integrating AI into business workflows. Nova makes it easy to work with LLMs and facilitates multi-agent workflows and interactive conversations.

## Features

- Integration with various LLM providers
- Multi-agent workflow orchestration
- Interactive conversation management
- OTP-based architecture for reliability and scalability

## Prerequisites

- Elixir 1.17 or later
- Erlang/OTP 26 or later

## Development Installation

```bash
git clone https://github.com/unoti/nova.git
cd nova
mix deps.get
```

Set environment variable `OPENAI_API_KEY`.

## Running Tests

Nova uses ExUnit's tag system to separate fast unit tests from slower integration tests.

```bash
mix test              # Run unit tests only
mix test.unit         # Unit tests only, here for symmetry
mix test.all          # All tests, including integration
mix test.integration  # Integration tests only
mix test.openai       # OpenAI integration tests only
```

### Running Specific Tests

To run tests for a specific module:

```bash
mix test test/nova/core/dialog_test.exs
```

## Project Structure

See to [Project Structure](docs/project_structure.md) for details on how the code is organized.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
