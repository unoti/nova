# Dialogs and Sessions

In this milestone we'll begin establish the foundational models
that we will work with.

At the heart of interacting with an LLM is the concept of
a dialog, which is a message history of who said what, when.

Here are the concepts:

* **Dialog**: The complete history of a discussion of things participants said.
    A Dialog consists of zero or more DialogRows.
* **DialogRow**: Someone someone said, and when they said it.
* **Session**: Contains a dialog, and adds additional information such as
    the identity of the user that initiated the conversation, as well as
    application-specific information to attach to that session.

* **SessionStorageProvider** can save, load, and list sessions.

## Implementation Notes for Elixir

After reviewing the Python implementation, here are the key design decisions for our Elixir implementation:

### Core Principles

1. **Immutability and Pure Functions**:
   - Use immutable data structures and pure functions
   - All operations return new versions of structures rather than modifying in place
   - Functions like `add_user` will return a new dialog with the added message

2. **Separation of Concerns**:
   - Token counting will be handled by LLM drivers, not the Dialog module
   - Metadata will be simplified and better structured

3. **Serialization**:
   - Leverage Elixir's natural serialization capabilities rather than custom serialization methods
   - Use libraries like Jason for JSON encoding/decoding when needed

### Proposed Structure

```elixir
defmodule Nova.Dialog.Role do
  @type t :: :user | :system | :assistant
end

defmodule Nova.Dialog.Row do
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
    role: Nova.Dialog.Role.t(),
    timestamp: DateTime.t(),
    metadata: map() | nil,
    images: list() | nil,
    processed: boolean()
  }
end

defmodule Nova.Dialog do
  @moduledoc """
  A conversation between a user and an LLM.
  """
  
  defstruct [
    :rows         # List of dialog rows
  ]
  
  @type t :: %__MODULE__{
    rows: [Nova.Dialog.Row.t()]
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
    metadata = if hidden, do: %{hide_row: true}, else: %{}
    add(dialog, :system, text, metadata)
  end
  
  # Add a message to the dialog
  def add(dialog, role, text, metadata \\ %{}, images \\ nil) do
    row = %Nova.Dialog.Row{
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
```

### Function Call Metadata

For storing function call information, we'll create a more structured approach:

```elixir
defmodule Nova.Dialog.FunctionCall do
  @moduledoc """
  A record of a function call made in a dialog.
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
```

This metadata can be incorporated into the dialog row's metadata field when needed.

### Next Steps

For the next phase, we'll:

1. Implement the core Dialog and DialogRow modules
2. Add proper type specifications
3. Add tests to verify functionality
4. Implement the Session module (in a later milestone)
