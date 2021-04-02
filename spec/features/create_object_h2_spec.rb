# frozen_string_literal: true

RSpec.describe 'Use H2 to create an object', type: :feature do
  let(:collection_title) { RandomWord.nouns.next }
  let(:item_title) { "SUL Logo for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h2_url}/dashboard", expected_text: 'Create a new collection')
  end

  scenario do
    click_button 'No' if page.has_content?('Continue your deposit', wait: 100)
    click_link '+ Create a new collection'

    # Checks for specific content on create collection view
    expect(page).to have_content('Manage release of deposits for discovery and download')

    # Fills in basic collection information and saves
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "Integration tests for #{collection_title}"
    fill_in 'Contact email', with: user_email

    # Select license
    select 'CC0-1.0', from: 'collection_required_license'

    # Adds user to depositor field
    fill_in 'Depositors', with: AuthenticationHelpers.username

    click_button 'Deposit'
    expect(page).to have_content(collection_title)

    # Can't deposit to a collection until it's ready. Use the edit link as a
    # signal that the background processes have finished before trying to
    # deposit an item to a collection.
    reload_page_until_timeout!(text: "Edit #{collection_title}", as_link: true)

    # Deposit an item to the collection
    find(:table, collection_title).sibling('turbo-frame').first(:button).click

    # Selects image type
    find('label', text: 'Image').click

    # Route to work deposit view
    click_button 'Continue'

    # Work Deposit view
    expect(page).to have_content('Deposit your content')
    attach_file('spec/fixtures/sul-logo.png') do
      find_button('Choose files').click
    end
    expect(page).to have_content('sul-logo.png')
    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email
    fill_in 'work_authors_attributes_0_first_name', with: 'Dana'
    fill_in 'work_authors_attributes_0_last_name', with: 'Scully'
    fill_in 'Abstract', with: "An abstract for #{collection_title} logo"
    fill_in 'Keywords', with: 'Integration test'
    # Blur keywords field so the client completes validation
    find_field('work_keywords').native.send_keys(:tab)

    check('I agree to the SDR Terms of Deposit')

    find_button('Deposit').click

    # Checks if title is on resulting display
    expect(page).to have_content(item_title)

    # This happens asynchronously, it might take a bit
    expect(page).to have_content('https://purl-stage.stanford.edu')

    # Opens Argo and searches on title
    visit Settings.argo_url

    find('input#q').fill_in(with: item_title)

    click_button 'Search'

    # Click on link with the item's title
    click_link item_title

    # Should be on item view
    find('h1', text: item_title)
  end
end
