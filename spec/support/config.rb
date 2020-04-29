# frozen_string_literal: true

require 'config'

# NOTE: For some reason `File.expand_path(__dir__, '../..')` did not do the right thing.
app_root = Pathname.new(__dir__).parent.parent

Config.load_and_set_settings(
  Config.setting_files(app_root, 'local')
)
