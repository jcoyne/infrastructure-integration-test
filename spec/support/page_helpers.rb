# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text:, as_link: false)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        # NOTE: Using passing `true` to this JavaScript function should force
        #       the browser to bypass its cache.
        page.evaluate_script('location.reload(true);')

        # NOTE: This could have been a ternary but I was concerned about its
        #       readability.
        if as_link
          break if page.has_link?(text)
        else
          break if page.has_text?(text)
        end
      end
    end
  end
end