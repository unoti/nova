
### Session Implementation

While we'll implement Sessions in a later milestone, here's the proposed design:

```elixir
defmodule Nova.Session do
  @moduledoc """
  A session contains a dialog plus metadata about the user and application.
  """
  
  defstruct [
    :id,            # Unique session identifier
    :user_id,       # ID of the user who owns this session
    :dialog,        # The dialog contained in this session
    :created_at,    # When the session was created
    :updated_at,    # When the session was last updated
    :app_data       # Application-specific data
  ]
  
  @type t :: %__MODULE__{
    id: String.t(),
    user_id: String.t(),
    dialog: Nova.Dialog.t(),
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    app_data: map()
  }
  
  # Create a new session
  def new(user_id, initial_prompt \\ nil) do
    now = DateTime.utc_now()
    dialog = Nova.Dialog.new(initial_prompt)
    
    %__MODULE__{
      id: generate_id(),
      user_id: user_id,
      dialog: dialog,
      created_at: now,
      updated_at: now,
      app_data: %{}
    }
  end
  
  # Add application-specific data to the session
  def put_app_data(session, key, value) do
    new_app_data = Map.put(session.app_data, key, value)
    %{session | app_data: new_app_data, updated_at: DateTime.utc_now()}
  end
  
  # Get application-specific data from the session
  def get_app_data(session, key, default \\ nil) do
    Map.get(session.app_data, key, default)
  end
  
  # Add a message to the dialog within this session
  def add_message(session, role, text, metadata \\ %{}, images \\ nil) do
    new_dialog = Nova.Dialog.add(session.dialog, role, text, metadata, images)
    %{session | dialog: new_dialog, updated_at: DateTime.utc_now()}
  end
  
  # Helper methods that delegate to dialog
  def add_user(session, text), do: add_message(session, :user, text)
  def add_assistant(session, text), do: add_message(session, :assistant, text)
  def add_system(session, text, hidden \\ false) do
    metadata = if hidden, do: %{hide_row: true}, else: %{}
    add_message(session, :system, text, metadata)
  end
  
  # Helper function to generate a unique ID
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
```

### Session Storage Provider

We'll also need a behavior for session storage:

```elixir
defmodule Nova.SessionStorageProvider do
  @moduledoc """
  Behaviour for implementing session storage providers.
  """
  
  @callback save(Nova.Session.t()) :: {:ok, Nova.Session.t()} | {:error, term()}
  @callback load(id :: String.t()) :: {:ok, Nova.Session.t()} | {:error, term()}
  @callback list(user_id :: String.t()) :: {:ok, [Nova.Session.t()]} | {:error, term()}
  @callback delete(id :: String.t()) :: :ok | {:error, term()}
end
```

This behavior can be implemented by different storage backends:

- `Nova.SessionStorage.Memory` - In-memory storage (for testing)
- `Nova.SessionStorage.File` - File-based storage
- `Nova.SessionStorage.Database` - Database storage (e.g., Postgres, Mnesia)

