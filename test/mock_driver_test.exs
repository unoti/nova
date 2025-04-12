defmodule MockDriverTest do
  use ExUnit.Case, async: true
  
  alias Nova.LLM.Drivers.Mock
  alias Nova.Entities.Dialog
  
  setup do
    # Reset the mock before each test
    Mock.reset_mock()
    :ok
  end
  
  test "returns default f(x) response" do
    {:ok, response} = Mock.chat("test input")
    assert response == "f(test input)"
  end
  
  test "returns preset response when set" do
    Mock.set_next_response("custom response")
    {:ok, response} = Mock.chat("ignored")
    assert response == "custom response"
  end
  
  test "reverts to default after using preset response" do
    # First set and use a preset response
    Mock.set_next_response("custom response")
    {:ok, _} = Mock.chat("first")
    
    # Then check we're back to default
    {:ok, response} = Mock.chat("second")
    assert response == "f(second)"
  end
end
