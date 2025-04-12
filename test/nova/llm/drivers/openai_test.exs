defmodule Nova.LLM.Drivers.OpenAITest do
  use ExUnit.Case, async: false
  
  # Tag as integration and external to allow selective running
  @moduletag :integration
  @moduletag :external
  
  alias Nova.LLM.Drivers.OpenAI
  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  
  # Skip by default, run only when explicitly included
  @tag :skip
  test "can make a simple chat completion" do
    # Skip this test by default unless explicitly included
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        IO.puts("Skipping OpenAI test: No API key set")
        :ok
        
      _ ->
        dialog = Dialog.new() |> Dialog.add_user("Hello, who are you?")
        
        assert {:ok, response} = OpenAI.chat_dialog(dialog)
        assert response.text != ""
        assert response.role == :assistant
        assert response.metadata.tokens.prompt > 0
        assert response.metadata.tokens.completion > 0
    end
  end
  
  @tag :skip
  test "can use structured output" do
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        IO.puts("Skipping OpenAI structured output test: No API key set")
        :ok
        
      _ ->
        schema = %{
          "name" => "string", 
          "age" => "number"
        }
        
        dialog = Dialog.new() |> Dialog.add_user("Create a fictional person with a name and age")
        
        assert {:ok, response} = OpenAI.chat_dialog_structured(dialog, schema)
        assert is_map(response)
        assert is_binary(response["name"])
        assert is_number(response["age"])
    end
  end
  
  @tag :skip
  test "can use tool calling" do
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        IO.puts("Skipping OpenAI tool calling test: No API key set")
        :ok
        
      _ ->
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
        
        dialog = Dialog.new() |> Dialog.add_user("What's the weather like in Tokyo?")
        
        assert {:ok, response} = OpenAI.chat_dialog_with_tools(dialog, tools)
        assert response.role == :assistant
        
        # Validate that we got a tool call in the response
        assert response.metadata.function_calls != nil
        assert length(response.metadata.function_calls) > 0
        
        function_call = List.first(response.metadata.function_calls)
        assert function_call.function_name == "get_weather"
        assert function_call.parameters["location"] =~ "Tokyo"
      end
  end
  
  @tag :skip
  test "handles API errors gracefully" do
    # Test with invalid API key to trigger error
    original_key = System.get_env("OPENAI_API_KEY")
    
    try do
      System.put_env("OPENAI_API_KEY", "invalid_key")
      
      dialog = Dialog.new() |> Dialog.add_user("This should fail")
      
      assert {:error, error} = OpenAI.chat_dialog(dialog)
      # The error should be an authentication error
      assert error.__struct__ == Nova.LLM.Driver.Errors.AuthenticationError
    after
      # Restore the original key
      if original_key do
        System.put_env("OPENAI_API_KEY", original_key)
      else
        System.delete_env("OPENAI_API_KEY")
      end
    end
  end
end
