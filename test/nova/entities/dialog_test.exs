defmodule Nova.Entities.DialogTest do
  use ExUnit.Case, async: true
  alias Nova.Entities.Dialog

  describe "new/2" do
    test "creates an empty dialog" do
      dialog = Dialog.new()
      assert dialog.rows == []
    end

    test "creates a dialog with initial system prompt" do
      initial_prompt = "You are a helpful assistant."
      dialog = Dialog.new(initial_prompt)
      
      assert length(dialog.rows) == 1
      [row] = dialog.rows
      assert row.role == :system
      assert row.text == initial_prompt
    end

    test "creates a dialog with initial prompt of specified role" do
      dialog = Dialog.new("Hello", :user)
      
      assert length(dialog.rows) == 1
      [row] = dialog.rows
      assert row.role == :user
      assert row.text == "Hello"
    end
  end

  describe "add_user/2" do
    test "adds a user message to the dialog" do
      dialog = Dialog.new()
      updated = Dialog.add_user(dialog, "How are you?")
      
      assert length(updated.rows) == 1
      [row] = updated.rows
      assert row.role == :user
      assert row.text == "How are you?"
    end
  end

  describe "add_assistant/2" do
    test "adds an assistant message to the dialog" do
      dialog = Dialog.new()
      updated = Dialog.add_assistant(dialog, "I'm doing well, thank you!")
      
      assert length(updated.rows) == 1
      [row] = updated.rows
      assert row.role == :assistant
      assert row.text == "I'm doing well, thank you!"
    end
  end

  describe "add_system/3" do
    test "adds a visible system message by default" do
      dialog = Dialog.new()
      updated = Dialog.add_system(dialog, "System instruction")
      
      assert length(updated.rows) == 1
      [row] = updated.rows
      assert row.role == :system
      assert row.text == "System instruction"
      assert row.metadata == nil
    end

    test "adds a hidden system message when specified" do
      dialog = Dialog.new()
      updated = Dialog.add_system(dialog, "Hidden instruction", true)
      
      assert length(updated.rows) == 1
      [row] = updated.rows
      assert row.role == :system
      assert row.text == "Hidden instruction"
      assert row.metadata.hidden == true
    end
  end

  describe "last_text/1" do
    test "returns empty string for empty dialog" do
      dialog = Dialog.new()
      assert Dialog.last_text(dialog) == ""
    end

    test "returns the text of the last message" do
      dialog = Dialog.new()
      |> Dialog.add_user("First message")
      |> Dialog.add_assistant("Second message")
      
      assert Dialog.last_text(dialog) == "Second message"
    end
  end

  describe "get_messages/2" do
    test "returns all messages for an empty role filter" do
      dialog = Dialog.new()
      |> Dialog.add_system("System message")
      |> Dialog.add_user("User message")
      |> Dialog.add_assistant("Assistant message")
      
      messages = Dialog.get_messages(dialog)
      assert length(messages) == 3
    end

    test "filters messages by role" do
      dialog = Dialog.new()
      |> Dialog.add_system("System message")
      |> Dialog.add_user("User message 1")
      |> Dialog.add_assistant("Assistant message")
      |> Dialog.add_user("User message 2")
      
      messages = Dialog.get_messages(dialog, :user)
      assert length(messages) == 2
      assert Enum.all?(messages, fn {role, _, _} -> role == :user end)
    end
  end
end