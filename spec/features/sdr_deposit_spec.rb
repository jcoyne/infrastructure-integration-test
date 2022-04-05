# frozen_string_literal: true

RSpec.describe 'SDR deposit', type: :feature do
  let(:start_url) { Settings.argo_url }
  let(:source_id) { "testing:#{SecureRandom.uuid}" }
  let(:catkey) { '10065784' }

  before do
    authenticate!(start_url: start_url, expected_text: 'Welcome to Argo!')
  end

  it 'deposits objects' do
    ensure_token
    object_druid = deposit(apo: Settings.default_apo,
                           collection: Settings.default_collection,
                           url: Settings.sdrapi_url,
                           source_id: source_id,
                           catkey: catkey,
                           accession: true,
                           view: 'world',
                           files: ['Gemfile', 'Gemfile.lock'],
                           files_metadata: {
                             'Gemfile' => { 'preserve' => true },
                             'Gemfile.lock' => { 'preserve' => true }
                           })

    visit "#{start_url}/view/#{object_druid}?beta=true"

    # Wait for indexing and workflows to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    expect(page).to have_content 'The means to prosperity'

    # Tests existence of technical metadata
    expect(page).to have_content 'Technical metadata'
    click_button 'Technical metadata'

    # this is a hack that forces the techMD section to scroll into view; the section
    # is lazily loaded, and won't actually be requested otherwise, even if the button
    # is clicked to expand the technical metadata section.
    page.execute_script 'window.scrollBy(0,100);'

    within('#document-techmd-section') do
      file_listing = find_all('.file')
      expect(file_listing.size).to eq 2
    end
  end
end
