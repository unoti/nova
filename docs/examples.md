# Nova: Examples & Use Cases

This document provides concrete examples of how Nova can be used to build AI-powered business applications, with a focus on supply chain scenarios.

## Basic Usage Examples

### Simple Text Generation

```elixir
defmodule MyApp.ContentGenerator do
  def generate_product_description(product) do
    prompt = """
    Create a compelling product description for:
    - Name: #{product.name}
    - Category: #{product.category}
    - Key features: #{Enum.join(product.features, ", ")}
    - Target audience: #{product.audience}
    
    The description should be approx. 100 words and highlight the unique value proposition.
    """
    
    {:ok, description} = Nova.generate(prompt, model: "gpt-4")
    description
  end
end
```

### Stateful Conversation

```elixir
defmodule MyApp.CustomerSupport do
  def handle_inquiry(customer_message, conversation_id) do
    # Retrieve or create conversation
    conversation = case Nova.Conversation.get(conversation_id) do
      {:ok, existing} -> existing
      {:error, :not_found} -> Nova.Conversation.new(
        system_prompt: customer_support_prompt(),
        metadata: %{customer_id: customer_message.customer_id}
      )
    end
    
    # Add the customer message and get AI response
    updated_conversation =
      conversation
      |> Nova.Conversation.add_message(:user, customer_message.content)
      |> Nova.Conversation.generate_response()
    
    # Save conversation state
    Nova.Conversation.save(updated_conversation)
    
    # Return the assistant's response
    Nova.Conversation.last_assistant_message(updated_conversation)
  end
  
  defp customer_support_prompt do
    """
    You are a helpful customer support assistant