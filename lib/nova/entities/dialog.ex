defmodule Nova.Entities.Dialog.Role do
  @moduledoc """
  Represents who said a message in a dialog.
  """
  
  @type t :: :user | :system | :assistant
end

defmodule Nova.Entities.Dialog.FunctionCall do
  @moduledoc """
  Represents a function call made during a dialog interaction.
  """
  
  defstruct [
    :function_name,  # Name of the function
    :parameters,     # Parameters passed to the function
    :result,         # Result of the function call
    :completion_id,  # ID of the completion
    :finish_reason   # Reason for finishing
  ]
  
  @type t :: %__MODULE__{
    function_name: String.t(),
    parameters: map(),
    result: map() | String.t() | nil,
    completion_id: String.t() | nil,
    finish_reason: String.t() | nil
  }
end

defmodule Nova.Entities.Dialog.RowMetadata do
  @moduledoc """
  Optional metadata for a dialog row.
  Only present for special dialog rows with function calls or other advanced features.
  """
  
  alias Nova.Entities.Dialog.FunctionCall
  
  defstruct [
    :function_calls,  # List of function calls if any were made
    :hidden,          # Whether this row should be hidden from the user
    :tokens,          # Token information if available
    :extra            # Any additional metadata as a map
  ]
  
  @type t :: %__MODULE__{
    function_calls: [FunctionCall.t()] | nil,
    hidden: boolean() | nil,
    tokens: map() | nil,
    extra: map() | nil
  }
end

defmodule Nova.Entities.Dialog.Row do
  @moduledoc """
  Represents one message in a dialog with its metadata.
  """
  
  alias Nova.Entities.Dialog.Role
  alias Nova.Entities.Dialog.RowMetadata
  
  defstruct [
    :text,          # What was said
    :role,          # Who said it (:user, :system, :assistant)
    :timestamp,     # When it was said
    :metadata,      # Optional metadata (function calls, etc.)
    :images,        # Optional images
    processed: true # Whether this has been processed by the LLM
  ]
  
  @type t :: %__MODULE__{
    text: String.t(),
    role: Role.t(),
    timestamp: DateTime.t(),
    metadata: RowMetadata.t() | nil,
    images: list() | nil,
    processed: boolean()
  }
end

defmodule Nova.Entities.Dialog do
  @moduledoc """
  A conversation between a user and an LLM.
  """
  
  alias Nova.Entities.Dialog.Role
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata
  
  defstruct [
    rows: []   # List of dialog rows
  ]
  
  @type t :: %__MODULE__{
    rows: [Row.t()]
  }
  
  @doc """
  Creates a new dialog, optionally with an initial prompt.

  ## Parameters
    * `initial_prompt` - Optional string message to start the dialog with
    * `role` - Who sent the initial message (:system, :user, or :assistant)

  ## Returns
    * A new `Nova.Entities.Dialog` struct
  """
  @spec new(initial_prompt :: String.t() | nil, role :: Role.t()) :: t()
  def new(initial_prompt \\ nil, role \\ :system) do
    dialog = %__MODULE__{rows: []}
    
    if initial_prompt do
      add(dialog, role, initial_prompt)
    else
      dialog
    end
  end
  
  @doc """
  Adds a message from a user to the dialog.

  ## Parameters
    * `dialog` - Existing dialog to which the message will be added
    * `text` - Text content of the user's message

  ## Returns
    * Updated dialog with the new message added
  """
  @spec add_user(dialog :: t(), text :: String.t()) :: t()
  def add_user(dialog, text), do: add(dialog, :user, text)
  
  @doc """
  Adds a message from the assistant to the dialog.

  ## Parameters
    * `dialog` - Existing dialog to which the message will be added
    * `text` - Text content of the assistant's message

  ## Returns
    * Updated dialog with the new message added
  """
  @spec add_assistant(dialog :: t(), text :: String.t()) :: t()
  def add_assistant(dialog, text), do: add(dialog, :assistant, text)
  
  @doc """
  Adds a system message to the dialog, optionally marking it as hidden.

  ## Parameters
    * `dialog` - Existing dialog to which the message will be added
    * `text` - Text content of the system message
    * `hidden` - Boolean indicating whether this message should be hidden from the user

  ## Returns
    * Updated dialog with the new system message added
  """
  @spec add_system(dialog :: t(), text :: String.t(), hidden :: boolean()) :: t()
  def add_system(dialog, text, hidden \\ false) do
    metadata = if hidden, do: %RowMetadata{hidden: true}, else: nil
    add(dialog, :system, text, metadata)
  end
  
  @doc """
  Adds a message to the dialog with specific role and optional metadata.

  ## Parameters
    * `dialog` - Existing dialog to which the message will be added
    * `role` - Who is sending the message (:user, :system, or :assistant)
    * `text` - Text content of the message
    * `metadata` - Optional metadata for the message
    * `images` - Optional list of images associated with the message

  ## Returns
    * Updated dialog with the new message added
  """
  @spec add(
    dialog :: t(), 
    role :: Role.t(), 
    text :: String.t(), 
    metadata :: RowMetadata.t() | nil, 
    images :: list() | nil
  ) :: t()
  def add(dialog, role, text, metadata \\ nil, images \\ nil) do
    row = %Row{
      text: text,
      role: role,
      timestamp: DateTime.utc_now(),
      metadata: metadata,
      images: images
    }
    
    %{dialog | rows: dialog.rows ++ [row]}
  end
  
  @doc """
  Gets the text of the last message in the dialog.

  ## Parameters
    * `dialog` - Dialog from which to retrieve the last message

  ## Returns
    * Text content of the last message, or empty string if dialog is empty
  """
  @spec last_text(dialog :: t()) :: String.t()
  def last_text(%{rows: []}), do: ""
  def last_text(%{rows: rows}), do: List.last(rows).text
  
  @doc """
  Gets a list of messages from the dialog, optionally filtered by role.

  ## Parameters
    * `dialog` - Dialog from which to retrieve messages
    * `role` - Optional role to filter messages by (:user, :system, :assistant, or nil for all)

  ## Returns
    * List of tuples {role, text, images} for each matching row
  """
  @spec get_messages(dialog :: t(), role :: Role.t() | nil) :: 
    [{Role.t(), String.t(), list() | nil}]
  def get_messages(dialog, role \\ nil) do
    dialog.rows
    |> maybe_filter_by_role(role)
    |> Enum.map(fn row -> {row.role, row.text, row.images} end)
  end
  
  @doc """
  Private helper function to filter rows by role if a role is provided.
  """
  @spec maybe_filter_by_role(
    rows :: [Row.t()], 
    role :: Role.t() | nil
  ) :: [Row.t()]
  defp maybe_filter_by_role(rows, nil), do: rows
  defp maybe_filter_by_role(rows, role), do: Enum.filter(rows, fn row -> row.role == role end)
end