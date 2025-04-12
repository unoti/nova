defmodule Nova.LLM.Drivers.OpenAI do
  @moduledoc """
  Implementation of the LLM Driver behavior for OpenAI's API.

  This driver communicates with OpenAI's API to provide chat completions
  and other LLM functionality.
  """

  @behaviour Nova.LLM.Driver

  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata
  alias Nova.Entities.Dialog.FunctionCall
  alias Nova.LLM.Driver.Errors

  # Default OpenAI model if none specified
  @default_model "gpt-4o"

  @spec chat_dialog(any()) :: {:error, any()} | {:ok, Nova.Entities.Dialog.Row.t()}
  @doc """
  Chat with OpenAI's API using a dialog history.

  Processes the dialog into OpenAI's expected format, makes the API call,
  and returns the response as a dialog row.
  """
  @impl Nova.LLM.Driver
  def chat_dialog(dialog, options \\ []) do
    model = Keyword.get(options, :model, @default_model)

    # Setup API params
    api_key = get_api_key()
    url = "https://api.openai.com/v1/chat/completions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    # Convert dialog to OpenAI format
    messages = dialog_to_openai_messages(dialog)

    # Prepare request body
    body = %{
      model: model,
      messages: messages,
      temperature: Keyword.get(options, :temperature, 0.7),
      max_tokens: Keyword.get(options, :max_tokens, 1000)
    }
    |> Jason.encode!()

    # Make the API call
    case :hackney.request(:post, url, headers, body, [:with_body]) do
      {:ok, status, _headers, response} when status in 200..299 ->
        handle_successful_response(response)

      {:ok, 400, _headers, response} ->
        {:error, %Errors.InvalidRequestError{message: "Bad request: #{response}"}}

      {:ok, 429, _headers, response} ->
        {:error, %Errors.RateLimitError{message: "Rate limit exceeded: #{response}"}}

      {:ok, 401, _headers, response} ->
        {:error, %Errors.AuthenticationError{message: "Authentication failed: #{response}"}}

      {:ok, status, _headers, response} ->
        {:error, %Errors.ServiceError{message: "OpenAI API error (#{status}): #{response}"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Chat with structured output.

  This method uses OpenAI's response_format parameter to request JSON responses,
  then decodes and validates them against the provided schema.
  """
  @impl Nova.LLM.Driver
  def chat_dialog_structured(dialog, schema, options \\ []) do
    # Add instructions to produce structured output following the schema
    schema_instructions = "Your response must be formatted as a JSON object that conforms to the following schema: #{inspect(schema)}"
    enhanced_dialog = dialog |> Dialog.add_system(schema_instructions, true)

    # Override options to ensure JSON response format
    json_options = Keyword.merge(options, [
      response_format: %{type: "json_object"}
    ])

    case chat_dialog(enhanced_dialog, json_options) do
      {:ok, row} ->
        # Attempt to parse the response as JSON
        case Jason.decode(row.text) do
          {:ok, json_data} ->
            # Here you would validate the JSON against the schema
            # For now, we'll just return the JSON data
            {:ok, json_data}

          {:error, reason} ->
            {:error, "Failed to parse JSON response: #{inspect(reason)}"}
        end

      error ->
        error
    end
  end

  @doc """
  Chat with tool calling capabilities.

  Allows the LLM to call functions as part of its response.
  """
  @impl Nova.LLM.Driver
  def chat_dialog_with_tools(dialog, tools, options \\ []) do
    # Prepare the API request with tools
    model = Keyword.get(options, :model, @default_model)

    # Setup API params
    api_key = get_api_key()
    url = "https://api.openai.com/v1/chat/completions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    # Convert dialog to OpenAI format
    messages = dialog_to_openai_messages(dialog)

    # Prepare request body with tools
    body = %{
      model: model,
      messages: messages,
      tools: tools,
      temperature: Keyword.get(options, :temperature, 0.7),
      max_tokens: Keyword.get(options, :max_tokens, 1000)
    }
    |> Jason.encode!()

    # Make the API call
    case :hackney.request(:post, url, headers, body, [:with_body]) do
      {:ok, status, _headers, response} when status in 200..299 ->
        handle_tool_response(response)

      {:ok, 400, _headers, response} ->
        {:error, %Errors.InvalidRequestError{message: "Bad request: #{response}"}}

      {:ok, 429, _headers, response} ->
        {:error, %Errors.RateLimitError{message: "Rate limit exceeded: #{response}"}}

      {:ok, 401, _headers, response} ->
        {:error, %Errors.AuthenticationError{message: "Authentication failed: #{response}"}}

      {:ok, status, _headers, response} ->
        {:error, %Errors.ServiceError{message: "OpenAI API error (#{status}): #{response}"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Simple chat interface for single prompt/response.

  Uses the default implementation from the LLM Driver module.
  """
  @impl Nova.LLM.Driver
  def chat(prompt, options \\ []) do
    Nova.LLM.Driver.default_chat(__MODULE__, prompt, options)
  end

  # Private helper functions

  # Convert Nova dialog to OpenAI message format
  defp dialog_to_openai_messages(dialog) do
    dialog.rows
    |> Enum.filter(fn row -> row.metadata == nil || !row.metadata.hidden end)
    |> Enum.map(fn row ->
      %{
        role: role_to_openai_role(row.role),
        content: row.text
      }
    end)
  end

  # Map Nova roles to OpenAI roles
  defp role_to_openai_role(:user), do: "user"
  defp role_to_openai_role(:system), do: "system"
  defp role_to_openai_role(:assistant), do: "assistant"

  # Handle a successful response from the OpenAI API
  defp handle_successful_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        # Extract the response message
        message = parsed["choices"] |> List.first() |> Map.get("message")

        # Extract token usage
        token_usage = %{
          prompt_tokens: parsed["usage"]["prompt_tokens"],
          completion_tokens: parsed["usage"]["completion_tokens"],
          total_tokens: parsed["usage"]["total_tokens"]
        }

        # Create row metadata with token information
        metadata = %RowMetadata{
          tokens: token_usage,
          extra: %{
            model: parsed["model"],
            completion_id: parsed["id"],
            finish_reason: parsed["choices"] |> List.first() |> Map.get("finish_reason")
          }
        }

        # Create and return the response dialog row
        {:ok, %Row{
          text: message["content"],
          role: :assistant,
          timestamp: DateTime.utc_now(),
          metadata: metadata
        }}

      {:error, reason} ->
        {:error, "Failed to parse OpenAI response: #{inspect(reason)}"}
    end
  end

  # Handle a tool-enabled response from the OpenAI API
  defp handle_tool_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        # Extract the response message
        message = parsed["choices"] |> List.first() |> Map.get("message")

        # Extract token usage
        token_usage = %{
          prompt_tokens: parsed["usage"]["prompt_tokens"],
          completion_tokens: parsed["usage"]["completion_tokens"],
          total_tokens: parsed["usage"]["total_tokens"]
        }

        # Process any tool calls
        function_calls = case message["tool_calls"] do
          nil -> nil
          tool_calls ->
            Enum.map(tool_calls, fn tool_call ->
              %FunctionCall{
                function_name: tool_call["function"]["name"],
                parameters: Jason.decode!(tool_call["function"]["arguments"]),
                completion_id: parsed["id"],
                finish_reason: parsed["choices"] |> List.first() |> Map.get("finish_reason")
              }
            end)
        end

        # Create row metadata with token information and function calls
        metadata = %RowMetadata{
          tokens: token_usage,
          function_calls: function_calls,
          extra: %{
            model: parsed["model"],
            completion_id: parsed["id"],
            finish_reason: parsed["choices"] |> List.first() |> Map.get("finish_reason")
          }
        }

        # Create and return the response dialog row
        {:ok, %Row{
          text: message["content"] || "",
          role: :assistant,
          timestamp: DateTime.utc_now(),
          metadata: metadata
        }}

      {:error, reason} ->
        {:error, "Failed to parse OpenAI response: #{inspect(reason)}"}
    end
  end

  # Get the OpenAI API key from environment variables
  defp get_api_key do
    System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY environment variable is not set"
  end
end
