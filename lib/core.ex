defmodule Yst.Core do
  @moduledoc """
  Yst.Core defines set of functions and features
  to be injected to modules with Scenario behaviour
  """

  @callback url :: String.t


  defmacro __using__(_opts) do
    quote do

      use Hound.Helpers
      require Logger

      alias Hound.Session
      alias Hound.Helpers.Cookie
      alias Hound.Helpers.Screenshot


      @doc """
      Defines base url of tested site
      """
      @spec url :: String.t
      def url, do: System.get_env "YS_URL"


      @doc """
      Defines username used on login panel
      """
      @spec user :: String.t
      def user, do: System.get_env "YS_LOGIN"


      @doc """
      Defines password used on login panel
      """
      @spec pass :: String.t
      def pass, do: System.get_env "YS_PASS"



      def expect_success statement do
        case statement do
          true ->
            Logger.info "Pass:(#{statement})"

          false ->
            Logger.error "Fail:(#{statement})"

          any ->
            Logger.warn "WrongArgument:(#{statement})"
        end
      end


      def expect_failure statement do
        case statement do
          true ->
            Logger.error "Fail:(#{statement})"

          false ->
            Logger.info "Pass:(#{statement})"

          any ->
            Logger.warn "WrongArgument:(#{statement})"
        end
      end

      @doc """
      Play scripted scenarios
      """
      @spec play(script :: [Scene.t]) :: any
      def play script do
        acts = length script

        for {scene, act} <- script |> Enum.with_index do
          scene_id = UUID.uuid4
          request = scene.req!

          # Process pre-request options
          if scene.session! do
            change_session_to scene_id
            Logger.debug "Using session: #{scene_id}"
          else
            change_to_default_session
            Logger.debug "Using default session"
          end

          if scene.cookies_reset! do
            delete_cookies
            Logger.debug "Done cookies reset"
          end

          # Get driver info
          {:ok, drver} = Hound.driver_info

          # Logger.info "Before Scene( #{act+1}/#{acts} ) Session( #{current_session_name} ) Url( #{url}#{request} )"
          # Logger.debug "B\n\
          #                 request: #{inspect request}\n\
          #              page_title: #{page_title}\n\
          #             current_url: #{current_url}\n\
          #                 cookies: #{inspect Cookie.cookies}\n\
          #              drver_info: #{inspect drver}\n\
          #            session_info: #{inspect Session.session_info Hound.current_session_id}\n\
          #            all_sessions: #{Enum.count(Session.active_sessions)}"

          navigate_to "#{url}#{request}"

          Logger.info "After Scene( #{act+1}/#{acts} ) Session( #{current_session_name} ) Url( #{url}#{request} )"
          Logger.debug "A\n\
                         scene_id: #{scene_id}\n\
                          request: #{inspect request}\n\
                       page_title: #{page_title}\n\
                      current_url: #{current_url}\n\
                          cookies: #{inspect Cookie.cookies}\n\
                       drver_info: #{inspect drver}\n\
                     session_info: #{inspect Session.session_info Hound.current_session_id}\n\
                     all_sessions: #{Enum.count(Session.active_sessions)}"

          # Fill
          for {html_entity, contents} <- scene.fill! do
            Logger.debug "Looking for entity: #{html_entity} to fill"
            for try_html_hook <- [:name, :id, :class] do # , :tag, :css
              if element? try_html_hook, html_entity do
                case search_element try_html_hook, html_entity do
                  {:ok, element} ->
                    Logger.debug "Found entity: #{try_html_hook} => #{html_entity}. Element: #{inspect element}"
                    fill_field element, contents

                  {:error, e} ->
                    Logger.error e

                end
              end
            end
          end


          for {html_entity, contents} <- scene.click! do
            Logger.debug "Looking for entity: #{html_entity} to click"
            for try_html_hook <- [:name, :id, :class, :tag, :css] do
              if element? try_html_hook, html_entity do
                case search_element try_html_hook, html_entity do
                  {:ok, element} ->
                    Logger.debug "Found entity: #{try_html_hook} => #{html_entity}. Click-Element: #{inspect element}"
                    click element

                  {:error, e} ->
                    Logger.error e

                end
              end
            end
          end


          #js!
          if scene.js? do
            for code <- scene.js! do
              Logger.debug "Executing JavaScript code: #{inspect code}"
              execute_script "#{code}"
            end
          else
            Logger.debug "JavaScript disabled for scene: #{scene_id}"
          end


          # accept! > dismiss!
          if scene.accept! do
            try do
              accept_dialog
              Logger.debug "Dialog accepted."
            rescue
              _ ->
                Logger.warn "Accepting dialog failed."
            end
          else
            if scene.dismiss! do
              try do
                dismiss_dialog
                Logger.debug "Dialog dismissed."
              rescue
                _ ->
                  Logger.warn "Dismissing dialog failed."
              end
            end
          end

          # keys!
          for symbol <- scene.keys! do
            Logger.debug "Sending keys: #{inspect symbol}"
            send_keys symbol
          end

          # Good time to make a shot!
          if scene.screenshot! do
            Logger.debug "Screenshot: scene_id: #{scene_id}"
            Screenshot.take_screenshot "screenshots/sceneid-#{scene_id}.png"
          end


          ###########
          #   Checks!
          ###############


          for title <- scene.title? do
            Logger.debug "CheckTitle:(#{title})"
            expect_success title == page_title
          end
          for title <- scene.title_not? do
            Logger.debug "CheckTitleNot:(#{title})"
            expect_failure title == page_title
          end

          for scrpt <- scene.script? do
            Logger.debug "CheckScript:(#{inspect scrpt})"
            expect_success (execute_script "#{scrpt}")
          end
          for scrpt <- scene.script_not? do
            Logger.debug "CheckScriptNot:(#{inspect scrpt})"
            expect_failure (execute_script "#{scrpt}")
          end

          for src <- scene.src? do
            Logger.debug "CheckSrc:(#{inspect src})"
            expect_success (String.contains? page_source, src)
          end
          for src <- scene.src_not? do
            Logger.debug "CheckSrcNot:(#{inspect src})"
            expect_failure (String.contains? page_source, src)
          end

          for text <- scene.text? do
            Logger.debug "CheckText:(#{inspect text})"
            expect_success (String.contains? visible_page_text, text)
          end
          for text <- scene.text_not? do
            Logger.debug "CheckTextNot:(#{inspect text})"
            expect_failure (String.contains? visible_page_text, text)
          end


        end


        # Available:
        # TODO: page_source
        # TODO: page_title
        # TODO: visible_page_text

        # TODO: it should return Result.t site data like html, text, fields DOM & stuff

        # NOTE: Return tripple with useful data:
        # Hound.end_session
      end


      @doc """
      Allow overriding only functions with corresponding arities
      """
      defoverridable [url: 0, user: 0, pass: 0, play: 1]

    end
  end

end
