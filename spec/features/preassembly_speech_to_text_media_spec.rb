# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if speech_to_text is enabled in the environment specific settings file
RSpec.describe 'Create a media object via Pre-assembly and ask for it be speechToTexted', if: Settings.speech_to_text.enabled do
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly.speech_to_text_bundle_directory } # where we will stage the media content
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_file_manifest_location) { 'tmp/file_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-media-stt-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "media-stt-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "media stt integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
    CSV
  end
  let(:preassembly_file_manifest_csv) do
    <<~CSV
      druid,filename,resource_label,sequence,publish,preserve,shelve,resource_type
      content,video_1.mp4,Video file 1,1,yes,yes,yes,video
      content,video_1.mpeg,Video file 1,1,no,yes,no,video
      content,video_1_thumb.jp2,Video file 1,1,yes,yes,yes,image
      content,video_2.mp4,Video file 2,2,yes,yes,yes,video
      content,video_2.mpeg,Video file 2,2,no,yes,no,video
      content,video_2_thumb.jp2,Video file 2,2,yes,yes,yes,image
      content,video_log.txt,Disc log file,5,no,yes,no,file
    CSV
  end

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
    FileUtils.rm_rf(bare_druid)
    unless bare_druid.empty?
      `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf \
      #{preassembly_bundle_dir}/#{bare_druid}`
    end
  end

  scenario do
    select 'integration-testing', from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'media', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Media Speech To Text via Preassembly'
    fill_in 'Source ID', with: "#{source_id}-#{random_alpha}"
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_druid = find('table a').text
    druid = "druid:#{bare_druid}"
    puts " *** preassembly media accessioning druid: #{druid} ***" # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # create file_manifest.csv file and scp it to preassembly staging directory
    File.write(local_file_manifest_location, preassembly_file_manifest_csv)
    `scp #{local_file_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_file_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this to
    #           give the page a moment to load so we fill in the full text field
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Media', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir
    choose 'batch_context_stt_available_false' # indicate media does not have pre-existing speech to text
    choose 'batch_context_run_stt_true' # yes, run speech to text
    choose 'batch_context_using_file_manifest_true' # use file manifest

    click_link_or_button 'Submit'
    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # go to job details page, download result
    first('td > a').click
    expect(page).to have_text preassembly_project_name

    # wait for preassembly background job to finish
    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link_or_button 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

    # ensure accessioning completed ... we should have two versions now,
    # with all files there, and an ocrWF, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    # Check that speechToTextWF ran
    reload_page_until_timeout!(text: 'speechToTextWF')

    # Wait for the second version accessioningWF to finish
    reload_page_until_timeout!(text: 'v2 Accessioned')

    # Check that the version description is correct for the second version
    reload_page_until_timeout!(text: 'Start SpeechToText workflow')

    # TODO: check that OCR was successful by looking for extra files that were created, and update expectations below

    files = all('tr.file')

    expect(files.size).to eq 7
    expect(files[0].text).to match(%r{video_1.mp4 video/mp4 1.4\d KB})
    expect(files[1].text).to match(%r{video_1.mpeg video/mpeg 64\.*\d* KB})
    expect(files[2].text).to match(%r{video_1_thumb.jp2 image/jp2 2\.*\d* KB})

    expect(files[3].text).to match(%r{video_2.mp4 video/mp4 1.4\d KB})
    expect(files[4].text).to match(%r{video_2.mpeg video/mpeg 64\.*\d* KB})
    expect(files[5].text).to match(%r{video_2_thumb.jp2 image/jp2 2\.*\d* KB})

    expect(files[6].text).to match(%r{video_log.txt text/plain 1\.*\d* KB})

    # TODO: Add expectations for the speech to text files when they are added to the object
    #
    expect(find_table_cell_following(header_text: 'Content type').text).to eq('media') # filled in by accessioning

    # check technical metadata for all non-thumbnail files
    reload_page_until_timeout! do
      click_link_or_button 'Technical metadata' # expand the Technical metadata section

      # this is a hack that forces the tech metadata section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?('v2 Accessioned', wait: 2)
    end
    page.has_text?('filetype', count: 6)
    page.has_text?('file_modification', count: 6)

    # The below confirms that preservation replication is working: we only replicate a
    # Moab version once it's been written successfully to on prem storage roots, and
    # we only log an event to dor-services-app after a version has successfully replicated
    # to a cloud endpoint.  So, confirming that both versions of our test object have
    # replication events logged for all three cloud endpoints is a good basic test of the
    # entire preservation flow.
    prefixed_druid = "druid:#{bare_druid}"
    druid_tree_str = DruidTools::Druid.new(prefixed_druid).tree.join('/')

    latest_s3_key = "#{druid_tree_str}.v0002.zip"
    reload_page_until_timeout! do
      click_link_or_button 'Events' # expand the Events section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?(latest_s3_key, wait: 3)
    end

    # the event log should eventually contain an event for replication of each version that
    # this test created to every endpoint we archive to
    poll_for_matching_events!(prefixed_druid) do |events|
      (1..2).all? do |cur_version|
        cur_s3_key = "#{druid_tree_str}.v000#{cur_version}.zip"

        %w[aws_s3_west_2 ibm_us_south aws_s3_east_1].all? do |endpoint_name|
          events.any? do |event|
            event[:event_type] == 'druid_version_replicated' &&
              event[:data]['parts_info'] &&
              event[:data]['parts_info'].size == 1 && # we only expect one part for this small object
              event[:data]['parts_info'].first['s3_key'] == cur_s3_key &&
              event[:data]['endpoint_name'] == endpoint_name
          end
        end
      end
    end

    # This section confirms the object has been published to PURL and has a
    # valid IIIF manifest
    # wait for the PURL name to be published by checking for collection name
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_text_on_purl_page(druid:, text: object_label)
    iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
    iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
    canvas_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, '@id')
    canvas = JSON.parse(Faraday.get(canvas_url).body)
    image_url = canvas.dig('images', 0, 'resource', '@id')
    image_response = Faraday.get(image_url)
    expect(image_response.status).to eq(200)
    expect(image_response.headers['content-type']).to include('image/jpeg')
  end
end