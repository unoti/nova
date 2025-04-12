.PHONY: test test-all test-integration test-openai

# Default to running only unit tests
test:
	mix test

# Run all tests including integration tests
test-all:
	mix test --include integration

# Run only integration tests
test-integration:
	mix test --only integration

# Run OpenAI integration tests (requires API key)
test-openai:
	mix test test/nova/llm/drivers/openai_test.exs --include skip
