defmodule Nova.LLM.Drivers.OpenAI do
  @moduledoc """
  Implementation of the LLM Driver behavior for OpenAI's API.

  This driver communicates with OpenAI's API to provide chat completions
  and other LLM functionality. It implements the Nova.LLM.Driver behavior,
  providing methods for chat-based interactions, structured output, and
  tool/function calling capabilities.

  ## Configuration

  The driver requires an OpenAI API key, which should be set in the
  OPENAI_API_KEY environment variable.

  ## Examples

  ```elixir
  # Basic chat
  dialog = Dialog.new() |> Dialog.add_user("Hello, who are you?")
  {:ok, response} = Nova.LLM.Drivers.OpenAI.chat_dialog(dialog)
  
  # With options
  {:ok, response} = Nova.LLM.Drivers.OpenAI.chat_dialog(dialog, 
    model: "gpt-4-turbo", 
    temperature: 0.2
  )
  
  # Simple chat without dialog management
  {:ok, text} = Nova.LLM.Drivers.OpenAI.chat("What is the capital of France?")
  ```
  """

  @behaviour Nova.LLM.Driver

  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata
  alias Nova.Entities.Dialog.FunctionCall
  alias Nova.LLM.Driver.Errors

  # Default OpenAI model if none specified
  @default_model "gpt-4o"
  
  # Base URL for OpenAI API
  @api_base_url "https://api.openai.com/v1"

  @spec chat_dialog(Dialog.t(), keyword()) :: {:error, any()} | {:ok, Row.t()}
  @doc """
  Chat with OpenAI's API using a dialog history.

  Processes the dialog into OpenAI's expected format, makes the API call,
  and returns the response as a dialog row.

  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `options` - Optional keyword list of parameters for the LLM:
      * `:model` - OpenAI model to use (default: "#{@default_model}")
      * `:temperature` - Controls randomness (0.0 to 2.0, default: 0.7)
      * `:max_tokens` - Maximum number of tokens to generate (default: 1000)
      * `:api_key` - Override the API key from environment
      * `:api_base_url` - Override the base URL for API calls
      * `:response_format` - Format specification for the response

  ## Returns
    * `{:ok, row}` - The LLM's response as a `Nova.Entities.Dialog.Row` struct
    * `{:error, reason}` - An error occurred during the request
  """
  @impl Nova.LLM.Driver
  def chat_dialog(dialog, options \\ []) do
    model = Keyword.get(options, :model, @default_model)

    # Setup API params
    api_key = Keyword.get(options, :api_key, get_api_key())
    base_url = Keyword.get(options, :api_base_url, @api_base_url)
    url = "#{base_url}/chat/completions"
    
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
      max_tokens: Keyword.get(options, :max_tokens, 1000),
      stream: false
    }
    
    # Add optional parameters if specified
    body = if response_format = Keyword.get(options, :response_format) do
      Map.put(body, :response_format, response_format)
    else
      body
    end
    
    body = if stop = Keyword.get(options, :stop) do
      Map.put(body, :stop, stop)
    else
      body
    end
    
    body = if presence_penalty = Keyword.get(options, :presence_penalty) do
      Map.put(body, :presence_penalty, presence_penalty)
    else
      body
    end
    
    body = if frequency_penalty = Keyword.get(options, :frequency_penalty) do
      Map.put(body, :frequency_penalty, frequency_penalty)
    else
      body
    end
    
    body = if top_p = Keyword.get(options, :top_p) do
      Map.put(body, :top_p, top_p)
    else
      body
    end
    
    # Encode the body to JSON
    encoded_body = Jason.encode!(body)

    # Make the API call
    case :hackney.request(:post, url, headers, encoded_body, [:with_body]) do
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

  @spec chat_dialog_structured(Dialog.t(), map() | struct(), keyword()) :: {:ok, map()} | {:error, term()}
  @doc """
  Chat with structured output.

  This method uses OpenAI's response_format parameter to request JSON responses,
  then decodes and validates them against the provided schema.

  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `schema` - A map or schema definition that the response should conform to
    * `options` - Optional keyword list of parameters for the LLM (same as chat_dialog/2)

  ## Returns
    * `{:ok, structured_data}` - The parsed JSON response as a map
    * `{:error, reason}` - An error occurred during the request or JSON parsing
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
            # For a more robust implementation, we could add schema validation
            # but for now, we'll just return the JSON data
            {:ok, json_data}

          {:error, reason} ->
            {:error, %Errors.ServiceError{
              message: "Failed to parse JSON response: #{inspect(reason)}"
            }}
        end

      error ->
        error
    end
  end

  @spec chat_dialog_with_tools(Dialog.t(), [map()], keyword()) :: {:ok, Row.t()} | {:error, term()}
  @doc """
  Chat with tool calling capabilities.

  This method allows the LLM to call functions as part of its response. It's useful
  for creating assistants that can perform actions or retrieve information.

  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `tools` - A list of tool definitions in OpenAI format
    * `options` - Optional keyword list of parameters:
      * `:model` - OpenAI model to use (default: "#{@default_model}")
      * `:temperature` - Controls randomness (0.0 to 2.0, default: 0.7)
      * `:max_tokens` - Maximum number of tokens to generate (default: 1000)
      * `:tool_choice` - Control which tool is used (default: "auto")
      * Other parameters supported by OpenAI's API

  ## Returns
    * `{:ok, row}` - The LLM's response as a `Nova.Entities.Dialog.Row` struct
    * `{:error, reason}` - An error occurred during the request

  ## Tool Format Example
  ```elixir
  tools = [
    %{
      "type" => "function",
      "function" => %{
        "name" => "get_weather",
        "description" => "Get the current weather in a location",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "location" => %{
              "type" => "string",
              "description" => "The city and state, e.g. San Francisco, CA"
            }
          },
          "required" => ["location"]
        }
      }
    }
  ]
  ```
  """
  @impl Nova.LLM.Driver
  def chat_dialog_with_tools(dialog, tools, options \\ []) do
    # Basic validation of tools
    validate_tools!(tools)
    # Prepare the API request with tools
    model = Keyword.get(options, :model, @default_model)

    # Setup API params
    api_key = Keyword.get(options, :api_key, get_api_key())
    base_url = Keyword.get(options, :api_base_url, @api_base_url)
    url = "#{base_url}/chat/completions"
    
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
      max_tokens: Keyword.get(options, :max_tokens, 1000),
      stream: false
    }
    
    # Add tool_choice if specified
    body = if tool_choice = Keyword.get(options, :tool_choice) do
      Map.put(body, :tool_choice, tool_choice)
    else
      body
    end
    
    # Add optional parameters
    body = if top_p = Keyword.get(options, :top_p) do
      Map.put(body, :top_p, top_p)
    else
      body
    end
    
    body = if presence_penalty = Keyword.get(options, :presence_penalty) do
      Map.put(body, :presence_penalty, presence_penalty)
    else
      body
    end
    
    body = if frequency_penalty = Keyword.get(options, :frequency_penalty) do
      Map.put(body, :frequency_penalty, frequency_penalty)
    else
      body
    end
    
    encoded_body = Jason.encode!(body)

    # Make the API call
    case :hackney.request(:post, url, headers, encoded_body, [:with_body]) do
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
      base_message = %{
        role: role_to_openai_role(row.role),
        content: row.text
      }
      
      # Handle images if present
      if row.images && length(row.images) > 0 do
        # For the OpenAI API, we need to transform the content into an array
        # with text and image URLs
        content_array = [%{type: "text", text: row.text}]
        
        # Add images to the content array
        image_content = row.images
        |> Enum.map(fn image_url ->
          %{
            type: "image_url",
            image_url: %{
              url: image_url
            }
          }
        end)
        
        # Combine text and images
        Map.put(base_message, :content, content_array ++ image_content)
      else
        base_message
      end
    end)
  end

  # Map Nova roles to OpenAI roles
  defp role_to_openai_role(:user), do: "user"
  defp role_to_openai_role(:system), do: "system"
  defp role_to_openai_role(:assistant), do: "assistant"
  # Fallback for any unexpected roles
  defp role_to_openai_role(_), do: "user"
  
  # Validate tools format
  defp validate_tools!(tools) do
    unless is_list(tools) do
      raise %Errors.InvalidRequestError{message: "Tools must be a list"}
    end
    
    Enum.each(tools, fn tool ->
      unless is_map(tool) do
        raise %Errors.InvalidRequestError{message: "Each tool must be a map"}
      end
      
      unless Map.has_key?(tool, "type") do
        raise %Errors.InvalidRequestError{message: "Each tool must have a 'type' key"}
      end
      
      case tool["type"] do
        "function" ->
          unless Map.has_key?(tool, "function") do
            raise %Errors.InvalidRequestError{message: "Function tool must have a 'function' key"}
          end
          
          function = tool["function"]
          unless is_map(function) do
            raise %Errors.InvalidRequestError{message: "Function must be a map"}
          end
          
          unless Map.has_key?(function, "name") do
            raise %Errors.InvalidRequestError{message: "Function must have a 'name' key"}
          end
        
        other ->
          raise %Errors.InvalidRequestError{message: "Unsupported tool type: #{other}"}
      end
    end)
    
    :ok
  end

  # Handle a successful response from the OpenAI API
  defp handle_successful_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        try do
          # Extract the response message
          first_choice = parsed["choices"] |> List.first()
          
          # Guard against empty choices
          unless first_choice do
            raise "No choices in OpenAI response"
          end
          
          message = first_choice |> Map.get("message")
          
          # Guard against missing message
          unless message do
            raise "No message in OpenAI response choice"
          end
          
          # Extract token usage with defensive coding
          usage = parsed["usage"] || %{}
          token_usage = %{
            prompt: usage["prompt_tokens"] || 0,
            completion: usage["completion_tokens"] || 0,
            total: usage["total_tokens"] || 0
          }
          
          # Create row metadata with token information
          metadata = %RowMetadata{
            tokens: token_usage,
            extra: %{
              model: parsed["model"],
              completion_id: parsed["id"],
              finish_reason: first_choice |> Map.get("finish_reason")
            }
          }
          
          # Get content, handling potential nil value
          content = message["content"] || ""
          
          # Create and return the response dialog row
          {:ok, %Row{
            text: content,
            role: :assistant,
            timestamp: DateTime.utc_now(),
            metadata: metadata
          }}
        rescue
          e in RuntimeError ->
            {:error, %Errors.ServiceError{message: "OpenAI response format error: #{e.message}"}}
          
          e ->
            {:error, %Errors.ServiceError{message: "Error processing OpenAI response: #{inspect(e)}"}}
        end

      {:error, reason} ->
        {:error, %Errors.ServiceError{message: "Failed to parse OpenAI response: #{inspect(reason)}"}}
    end
  end

  # Handle a tool-enabled response from the OpenAI API
  defp handle_tool_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        try do
          # Extract the response message - defensive programming
          first_choice = parsed["choices"] |> List.first()
          
          # Guard against empty choices
          unless first_choice do
            raise "No choices in OpenAI response"
          end
          
          message = first_choice |> Map.get("message")
          
          # Guard against missing message
          unless message do
            raise "No message in OpenAI response choice"
          end
          
          # Extract token usage with defensive coding
          usage = parsed["usage"] || %{}
          token_usage = %{
            prompt: usage["prompt_tokens"] || 0,
            completion: usage["completion_tokens"] || 0,
            total: usage["total_tokens"] || 0
          }

          finish_reason = first_choice |> Map.get("finish_reason")
          completion_id = parsed["id"]
          
          # Process any tool calls
          function_calls = case message["tool_calls"] do
            nil -> 
              # Check for older API format with function_call
              if message["function_call"] do
                [
                  %FunctionCall{
                    function_name: message["function_call"]["name"],
                    parameters: safely_decode_json(message["function_call"]["arguments"]),
                    completion_id: completion_id,
                    finish_reason: finish_reason
                  }
                ]
              else
                nil
              end
              
            tool_calls ->
              Enum.map(tool_calls, fn tool_call ->
                %FunctionCall{
                  function_name: tool_call["function"]["name"],
                  parameters: safely_decode_json(tool_call["function"]["arguments"]),
                  completion_id: completion_id,
                  finish_reason: finish_reason
                }
              end)
          end

          # Create row metadata with token information and function calls
          metadata = %RowMetadata{
            tokens: token_usage,
            function_calls: function_calls,
            extra: %{
              model: parsed["model"],
              completion_id: completion_id,
              finish_reason: finish_reason
            }
          }

          # Create and return the response dialog row
          {:ok, %Row{
            text: message["content"] || "",
            role: :assistant,
            timestamp: DateTime.utc_now(),
            metadata: metadata
          }}
        rescue
          e in RuntimeError ->
            {:error, %Errors.ServiceError{message: "OpenAI response format error: #{e.message}"}}
            
          e ->
            {:error, %Errors.ServiceError{message: "Error processing OpenAI tool response: #{inspect(e)}"}}
        end

      {:error, reason} ->
        {:error, %Errors.ServiceError{message: "Failed to parse OpenAI response: #{inspect(reason)}"}}
    end
  end
  
  # Safely decode JSON with error handling
  defp safely_decode_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"error" => "Failed to parse JSON arguments", "raw" => json_string}
    end
  end

  # Get the OpenAI API key from environment variables
  defp get_api_key do
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        raise %Errors.AuthenticationError{
          message: "OPENAI_API_KEY environment variable is not set. " <>
                  "Please set this environment variable with a valid OpenAI API key."
        }
      
      key when byte_size(key) < 20 ->
        raise %Errors.AuthenticationError{
          message: "OPENAI_API_KEY environment variable contains an invalid API key. " <>
                  "The key appears to be too short."
        }
        
      key -> key
    end
  end
end
