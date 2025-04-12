defmodule Nova.LLM.Drivers.MockTest do
  use ExUnit.Case, async: true

  alias Nova.LLM.Drivers.MockLlm
  alias Nova.Entities.Dialog
  alias Nova.Entities.Dialog.Row
  alias Nova.Entities.Dialog.RowMetadata

  setup do
    # Reset the mock before each test
    MockLlm.reset_mock()
    :ok
  end

  describe "chat/2" do
    test "returns f(x) by default" do
      {:ok, response} = MockLlm.chat("hello world")
      assert response == "f(hello world)"
    end

    test "returns predetermined response when set" do
      MockLlm.set_next_response("custom response")
      {:ok, response} = MockLlm.chat("ignored input")
      assert response == "custom response"
    end

    test "reverts to default behavior after using predetermined response" do
      # First call - predetermined
      MockLlm.set_next_response("custom response")
      {:ok, response1} = MockLlm.chat("first input")
      assert response1 == "custom response"

      # Second call - should revert to default
      {:ok, response2} = MockLlm.chat("second input")
      assert response2 == "f(second input)"
    end
  end

  describe "chat_dialog/2" do
    test "uses the last user message for default responses" do
      dialog = Dialog.new()
               |> Dialog.add_user("first message")
               |> Dialog.add_assistant("some response")
               |> Dialog.add_user("last message")

      {:ok, row} = MockLlm.chat_dialog(dialog)
      assert row.text == "f(last message)"
      assert row.role == :assistant
    end

    test "returns predetermined response when set" do
      dialog = Dialog.new() |> Dialog.add_user("some input")

      MockLlm.set_next_response("preset dialog response")
      {:ok, row} = MockLlm.chat_dialog(dialog)
      assert row.text == "preset dialog response"
    end
  end

  describe "chat_dialog_structured/3" do
    test "returns structured data based on last message" do
      dialog = Dialog.new() |> Dialog.add_user("structured")
      schema = %{name: "", value: ""}

      {:ok, data} = MockLlm.chat_dialog_structured(dialog, schema)
      assert data.name == "f(structured).name"
      assert data.value == "f(structured).value"
    end

    test "returns predetermined structured data when set" do
      dialog = Dialog.new() |> Dialog.add_user("ignored")
      schema = %{anything: ""}

      MockLlm.set_next_structured_response(%{custom: "data", other: 123})
      {:ok, data} = MockLlm.chat_dialog_structured(dialog, schema)
      assert data.custom == "data"
      assert data.other == 123
    end
  end

  describe "chat_dialog_with_tools/3" do
    test "uses the first tool by default" do
      dialog = Dialog.new() |> Dialog.add_user("tool input")
      tools = [
        %{
          "type" => "function",
          "function" => %{
            "name" => "test_function",
            "description" => "A test function"
          }
        }
      ]

      {:ok, row} = MockLlm.chat_dialog_with_tools(dialog, tools)
      [function_call] = row.metadata.function_calls
      assert function_call.function_name == "test_function"
      assert function_call.parameters["input"] == "f(tool input)"
    end

    test "returns text response when no tools provided" do
      dialog = Dialog.new() |> Dialog.add_user("no tools")

      {:ok, row} = MockLlm.chat_dialog_with_tools(dialog, [])
      assert row.text == "f(no tools)"
      refute row.metadata.function_calls
    end

    test "returns predetermined text when set" do
      dialog = Dialog.new() |> Dialog.add_user("ignored")
      tools = [%{"function" => %{"name" => "ignored"}}]

      MockLlm.set_next_tool_text_response("custom tool text")
      {:ok, row} = MockLlm.chat_dialog_with_tools(dialog, tools)
      assert row.text == "custom tool text"
      refute row.metadata.function_calls
    end

    test "returns predetermined function call when set" do
      dialog = Dialog.new() |> Dialog.add_user("ignored")
      tools = [%{"function" => %{"name" => "ignored"}}]

      function_call = %{
        function_name: "custom_function",
        parameters: %{"param1" => "value1", "param2" => 42},
        result: nil,
        completion_id: nil,
        finish_reason: nil
      }

      MockLlm.set_next_tool_function_call(function_call)
      {:ok, row} = MockLlm.chat_dialog_with_tools(dialog, tools)
      [returned_function_call] = row.metadata.function_calls
      assert returned_function_call == function_call
      assert row.text == ""
    end
  end
end
