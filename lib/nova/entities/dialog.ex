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
  
  defstruct [
    :function_calls,  # List of function calls if any were made
    :hidden,          # Whether this row should be hidden from the user
    :tokens,          # Token information if available
    :extra            # Any additional metadata as a map
  ]
  
  @type t :: %__MODULE__{
    function_calls: [Nova.Entities.Dialog.FunctionCall.t()] | nil,
    hidden: boolean() | nil,
    tokens: map() | nil,
    extra: map() | nil
  }
end

defmodule Nova.Entities.Dialog.Row do
  @moduledoc """
  Represents one message in a dialog with its metadata.
  """
  
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
    role: Nova.Entities.Dialog.Role.t(),
    timestamp: DateTime.t(),
    metadata: Nova.Entities.Dialog.RowMetadata.t() | nil,
    images: list() | nil,
    processed: boolean()
  }
end

defmodule Nova.Entities.Dialog do
  @moduledoc """
  A conversation between a user and an LLM.
  """
  
  defstruct [
    rows: []   # List of dialog rows
  ]
  
  @type t :: %__MODULE__{
    rows: [Nova.Entities.Dialog.Row.t()]
  }
  
  # Create a new dialog, optionally with an initial prompt
  def new(initial_prompt \\ nil, role \\ :system) do
    dialog = %__MODULE__{rows: []}
    
    if initial_prompt do
      add(dialog, role, initial_prompt)
    else
      dialog
    end
  end
  
  # Add a message from a user
  def add_user(dialog, text), do: add(dialog, :user, text)
  
  # Add a message from the assistant
  def add_assistant(dialog, text), do: add(dialog, :assistant, text)
  
  # Add a system message
  def add_system(dialog, text, hidden \\ false) do
    metadata = if hidden, do: %Nova.Entities.Dialog.RowMetadata{hidden: true}, else: nil
    add(dialog, :system, text, metadata)
  end
  
  # Add a message to the dialog
  def add(dialog, role, text, metadata \\ nil, images \\ nil) do
    row = %Nova.Entities.Dialog.Row{
      text: text,
      role: role,
      timestamp: DateTime.utc_now(),
      metadata: metadata,
      images: images
    }
    
    %{dialog | rows: dialog.rows ++ [row]}
  end
  
  # Get the last message in the dialog
  def last_text(%{rows: []}), do: ""
  def last_text(%{rows: rows}), do: List.last(rows).text
  
  # Get a list of messages, optionally filtered by role
  def get_messages(dialog, role \\ nil) do
    dialog.rows
    |> maybe_filter_by_role(role)
    |> Enum.map(fn row -> {row.role, row.text, row.images} end)
  end
  
  defp maybe_filter_by_role(rows, nil), do: rows
  defp maybe_filter_by_role(rows, role), do: Enum.filter(rows, fn row -> row.role == role end)
end