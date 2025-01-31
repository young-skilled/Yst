defmodule HeadlessScene do
  @moduledoc """
  Scenario for general headless browser tests.
  """

  use Core

  @behaviour Scenario


  def script, do: [

      %Scene {
        name: "handle-confirm-alert",
        req!: "/",
        js!: ["return window.isItReal = confirm('Is it true?')"],
        script_not?: ["return window.isItReal"],
      },

      %Scene {
        name: "handle-dismiss-alert",
        req!: "/",
        js!: ["return alert('Is it true?')"],
        dismiss!: true,
        script?: ["return true"]
      },

  ]

end
