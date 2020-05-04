# frozen_string_literal: true

module AuthenticationHelpers
  def authenticate!(start_url:, expected_text:)
    @@username ||= Settings.sunet.id || begin
      print 'SUNet ID: '
      username = $stdin.gets
      username.strip
    end

    @@password ||= Settings.sunet.password || begin
      print 'Password: '
      password = $stdin.noecho(&:gets)
      # So the user knows we're off the password prompt
      puts
      password.strip
    end

    # View the specified starting URL
    visit start_url

    # We're at the Stanford login page
    if page.has_content?('SUNet ID')
      fill_in 'SUNet ID', with: @@username
      fill_in 'Password', with: @@password
      sleep 1
      click_button 'Login'

      within_frame('duo_iframe') do
        click_button 'Send Me a Push'
      end
    end

    using_wait_time 100 do
      # Once we see this we know the log in succeeded.
      expect(page).to have_content expected_text
    end
  end

  def ensure_token
    @@token ||= begin
      visit "#{BASE_URL}/settings/tokens"
      click_button 'Generate new token'
      find_field('Token').value.tap do |token|
        SdrClient::Credentials.write(token)
      end
    end
  end
end
