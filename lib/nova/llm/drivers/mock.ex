defmodule Nova.LLM.Drivers.Mock do
  @moduledoc """
  A mock LLM driver for testing purposes.
  
  This driver provides predictable responses for testing:
  
  1. By default, if the last message in the dialog is "x", it will return "f(x)"
  2. For more controlled testing, you can set a specific response to be returned on the next call
  
  ## Example Usage
  
  ```elixir
  # Default behavior - returns f(prompt)
  {:ok, row} = Nova.LLM.Drivers.Mock.chat("hello")
  # row.text will be "f(hello)"
  
  # Setting a predetermined response
  Nova.LLM.Drivers.Mock.set_next_response("predefined answer")
  {:ok, row} = Nova.LLM.Drivers.Mock.chat("hello")
  # row.text will be "predefined answer"
  
  # Reset to default behavior automatically after using the predetermined response
  {:ok, row} = Nova.LLM.Drivers.Mock.chat("hello again")
  # row.text will be "f(hello again)"
  ```
  """
  
  @behaviour Nova.LLM.Driver
  
  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata
  alias Nova.Entities.Dialog.FunctionCall
  
  @doc """
  Set a predetermined response for the next LLM call.
  This response will be used only once, then the driver will revert to default behavior.
  """
  def set_next_response(response) do
    Process.put(:mock_llm_next_response, response)
    :ok
  end
  
  @doc """
  Reset the mock driver, clearing any predetermined responses.
  """
  def reset_mock do
    Process.delete(:mock_llm_next_response)
    Process.delete(:mock_llm_next_structured_response)
    Process.delete(:mock_llm_next_tool_response)
    :ok
  end
  
  @impl true
  def chat_dialog(dialog, _options \\ []) do
    case Process.get(:mock_llm_next_response) do
      nil -> 
        # Default behavior: generate f(x) for the last message x
        last_message = get_last_message(dialog)
        default_response = "f(#{last_message})"
        create_assistant_row(default_response)
        
      response ->
        # Use the predetermined response and reset
        Process.put(:mock_llm_next_response, nil)
        create_assistant_row(response)
    end
  end
  
  @impl true
  def chat_dialog_structured(dialog, schema, options \\ []) do
    case Process.get(:mock_llm_next_structured_response) do
      nil ->
        # Default behavior: create a simple map that matches the schema keys with values from the last message
        last_message = get_last_message(dialog)
        
        # Assuming schema is a map with expected keys
        # If it's something more complex, this would need to be adjusted
        structured_data = if is_map(schema) do
          Map.new(Map.keys(schema), fn key -> {key, "f(#{last_message}).#{key}"} end)
        else
          %{result: "f(#{last_message})"}
        end
        
        {:ok, structured_data}
        
      response ->
        # Use the predetermined structured response and reset
        Process.put(:mock_llm_next_structured_response, nil)
        {:ok, response}
    end
  end
  
  @doc """
  Set a predetermined structured response for the next structured LLM call.
  """
  def set_next_structured_response(response) do
    Process.put(:mock_llm_next_structured_response, response)
    :ok
  end
  
  @impl true
  def chat_dialog_with_tools(dialog, tools, options \\ []) do
    case Process.get(:mock_llm_next_tool_response) do
      nil ->
        # Default behavior: if tools are available, use the first one
        last_message = get_last_message(dialog)
        
        if tools && length(tools) > 0 do
          # Create a function call using the first tool
          tool = List.first(tools)
          function_call = %{
            function_name: tool["function"]["name"],
            parameters: %{"input" => "f(#{last_message})"},
            result: nil,
            completion_id: nil,
            finish_reason: nil
          }
          
          metadata = %RowMetadata{
            function_calls: [function_call],
            tokens: %{completion: 20, prompt: 10, total: 30}
          }
          
          {:ok, %Row{
            role: :assistant,
            text: "",
            timestamp: DateTime.utc_now(),
            metadata: metadata
          }}
        else
          # No tools, just return a regular response
          create_assistant_row("f(#{last_message})")
        end
        
      {type, response} when type in [:text, :function_call] ->
        # Use the predetermined response based on type
        Process.put(:mock_llm_next_tool_response, nil)
        
        case type do
          :text -> create_assistant_row(response)
          :function_call -> 
            metadata = %RowMetadata{
              function_calls: [response],
              tokens: %{completion: 20, prompt: 10, total: 30}
            }
            
            {:ok, %Row{
              role: :assistant,
              text: "",
              timestamp: DateTime.utc_now(),
              metadata: metadata
            }}
        end
    end
  end
  
  @doc """
  Set a predetermined text response for the next tools-enabled LLM call.
  """
  def set_next_tool_text_response(response) do
    Process.put(:mock_llm_next_tool_response, {:text, response})
    :ok
  end
  
  @doc """
  Set a predetermined function call for the next tools-enabled LLM call.
  """
  def set_next_tool_function_call(function_call) do
    Process.put(:mock_llm_next_tool_response, {:function_call, function_call})
    :ok
  end
  
  @impl true
  def chat(prompt, options \\ []) do
    Nova.LLM.Driver.default_chat(__MODULE__, prompt, options)
  end
  
  # Helper functions
  
  defp get_last_message(dialog) do
    # Get the text from the last user message
    dialog.rows
    |> Enum.reverse()
    |> Enum.find_value("empty prompt", fn row ->
      if row.role == :user, do: row.text, else: nil
    end)
  end
  
  defp create_assistant_row(text) do
    metadata = %RowMetadata{
      tokens: %{
        completion: String.length(text),
        prompt: 10, # Arbitrary value for testing
        total: String.length(text) + 10
      }
    }
    
    {:ok, %Row{
      role: :assistant,
      text: text,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }}
  end
end
