defmodule Yst do
  @moduledoc "YoungSkilled OST"

  require Logger
  use Hound.Helpers


  def main, do: main []
  def main _ do
    run
  end


  def run do
    case Application.start :hound do
      :ok ->
        Logger.info "Hounds unleashed."

      {:error, cause} ->
        case cause do
          {:already_started, :hound} ->
            Logger.info "Hounds already unleased."

          {reason, :hound} ->
            Logger.error "Hounds were lost. Cause: #{inspect reason}"
        end
    end

    Hound.start_session

    navigate_to "http://akash.im"
    Logger.info page_title()

    # Automatically invoked if the session owner process crashes
    Hound.end_session
  end
end

# Yst.run
