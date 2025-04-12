defmodule Nova.LLM.Driver do
  @moduledoc """
  Behavior for LLM drivers in Nova.
  
  An LLM Driver provides a minimal interface for direct communication with 
  Language Learning Model services. It handles the specific details of 
  communicating with a particular LLM implementation, whether it's an external 
  API service or a local model.
  
  Drivers should focus solely on LLM interaction, avoiding cross-cutting concerns
  like logging, metrics, or other auxiliary features.
  
  This behavior defines the core functionality that all LLM drivers must implement.
  The main method is `chat_dialog/2`, from which other convenience methods can be built.
  """
  
  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata
  alias Nova.Entities.Dialog.FunctionCall
  
  @doc """
  Given a dialog (conversation history), generate a response from the LLM.
  
  This is the core method that all drivers must implement. It takes a dialog containing
  the conversation history and returns a dialog row representing the LLM's response.
  
  The driver implementation is responsible for:
  1. Converting the dialog to the format required by the underlying LLM
  2. Making the API call to the LLM
  3. Converting the response to a `Nova.Entities.Dialog.Row` struct
  4. Including token usage information in the response
  
  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `options` - Optional keyword list of parameters for the LLM (e.g., temperature, model)
  
  ## Returns
    * `{:ok, row}` - The LLM's response as a `Nova.Entities.Dialog.Row` struct
    * `{:error, reason}` - An error occurred during the request
  """
  @callback chat_dialog(dialog :: Dialog.t(), options :: keyword()) ::
    {:ok, Row.t()} | {:error, term()}
  
  @doc """
  Similar to chat_dialog/2, but returns a structured response as a map.
  
  This method is used when you want the LLM to respond with structured data
  rather than free-form text. The response will be validated against the
  provided schema.
  
  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `schema` - A map or module defining the expected response structure
    * `options` - Optional keyword list of parameters for the LLM
  
  ## Returns
    * `{:ok, structured_data}` - The validated structured response
    * `{:error, reason}` - An error occurred during the request
  """
  @callback chat_dialog_structured(dialog :: Dialog.t(), schema :: term(), options :: keyword()) ::
    {:ok, map()} | {:error, term()}
  
  @doc """
  Similar to chat_dialog/2, but provides tools that the LLM can use in its response.
  
  This method allows the LLM to call functions/tools when generating its response.
  
  ## Parameters
    * `dialog` - A `Nova.Entities.Dialog` struct containing the conversation history
    * `tools` - A list of tool definitions that the LLM can use
    * `options` - Optional keyword list of parameters for the LLM
  
  ## Returns
    * `{:ok, row}` - The LLM's response, which may include tool calls
    * `{:error, reason}` - An error occurred during the request
  """
  @callback chat_dialog_with_tools(dialog :: Dialog.t(), tools :: [map()], options :: keyword()) ::
    {:ok, Row.t()} | {:error, term()}
  
  @doc """
  Convenience method for simple chat interactions.
  
  This method provides a simplified interface for when you just need to send
  a single prompt and get a response, without managing dialog history.
  
  ## Parameters
    * `prompt` - A string prompt to send to the LLM
    * `options` - Optional keyword list of parameters for the LLM
  
  ## Returns
    * `{:ok, response}` - The text response from the LLM
    * `{:error, reason}` - An error occurred during the request
  
  Note: This is an optional callback with a default implementation provided.
  """
  @callback chat(prompt :: String.t(), options :: keyword()) ::
    {:ok, String.t()} | {:error, term()}
    
  @optional_callbacks [chat: 2]
  
  @doc """
  Helper module function to provide a default implementation of chat/2.
  
  Driver modules can use this by doing:
  ```
  def chat(prompt, options \\ []) do
    Nova.LLM.Driver.default_chat(__MODULE__, prompt, options)
  end
  ```
  """
  def default_chat(driver_module, prompt, options \\ []) do
    # Create a new dialog with just the user prompt
    dialog = Dialog.new() |> Dialog.add_user(prompt)
    
    case driver_module.chat_dialog(dialog, options) do
      {:ok, row} -> {:ok, row.text}
      error -> error
    end
  end
  
  @doc """
  Error types that can be used by driver implementations.
  """
  defmodule Errors do
    defmodule InvalidRequestError do
      defexception [:message]
    end
    
    defmodule RateLimitError do
      defexception [:message]
    end
    
    defmodule AuthenticationError do
      defexception [:message]
    end
    
    defmodule ServiceError do
      defexception [:message]
    end
  end
end
