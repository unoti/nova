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

## Installation

Once published to [Hex](https://hex.pm/docs/publish), you can install the package by adding `nova` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nova, "~> 0.1.0"}
  ]
end
```

For development:

```bash
git clone https://github.com/yourusername/nova.git
cd nova
mix deps.get
```

## Running Tests

Run the test suite with:

```bash
mix test
```

To run tests for a specific module:

```bash
mix test test/nova/core/dialog_test.exs
```

## Usage

```elixir
# Basic example coming soon
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

Once published, the docs can be found at <https://hexdocs.pm/nova>.

## Project Structure

Refer to [Project Structure](docs/project_structure.md) for details on how the code is organized.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
