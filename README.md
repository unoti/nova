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

### Regular Development (Fast)

Run only the unit tests (excludes integration and external tests):

```bash
mix test
```

### Integration Tests 

Run all tests including integration tests:

```bash
mix test --include integration
```

Run only integration tests:

```bash
mix test --only integration
```

### External API Tests

Some tests require external API credentials (like OpenAI API keys). These are tagged with both `:integration` and `:external`.

To run tests that require the OpenAI API:

```bash
OPENAI_API_KEY=your_api_key mix test --include external
```

### Running Specific Tests

To run tests for a specific module:

```bash
mix test test/nova/core/dialog_test.exs
```

To run a specific test that would normally be skipped:

```bash
mix test test/path/to/test.exs:line_number --include skip
```

### Using the Makefile

For convenience, a Makefile is provided with common test commands:

```bash
# Run only unit tests (fast)
make test

# Run all tests including integration tests
make test-all

# Run only integration tests
make test-integration

# Run OpenAI integration tests (requires API key)
make test-openai
```

## Usage

```elixir
# Basic example coming soon
```

## Project Structure

See to [Project Structure](docs/project_structure.md) for details on how the code is organized.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
