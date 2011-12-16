require 'test_helper'

class Admin::PublicationsControllerTest < ActionController::TestCase
  setup do
    @user = login_as :policy_writer
  end

  should_be_an_admin_controller

  should_allow_organisations_for :publication
  should_allow_ministerial_roles_for :publication
  should_allow_attachments_for :publication
  should_display_attachments_for :publication
  should_be_rejectable :publication
  should_be_force_publishable :publication
  should_be_able_to_delete_a_document :publication
  should_link_to_public_version_when_published :publication
  should_not_link_to_public_version_when_not_published :publication
  should_prevent_modification_of_unmodifiable :publication

  test "new displays publication fields" do
    get :new

    assert_select "form#document_new" do
      assert_select "select[name*='document[publication_date']", count: 3
      assert_select "input[name='document[unique_reference]'][type='text']"
      assert_select "input[name='document[isbn]'][type='text']"
      assert_select "input[name='document[research]'][type='checkbox']"
      assert_select "input[name='document[order_url]'][type='text']"
    end
  end

  test 'creating should create a new publication' do
    first_policy = create(:published_policy)
    second_policy = create(:published_policy)
    attributes = attributes_for(:publication,
      publication_date: Date.parse("1805-10-21"),
      unique_reference: "unique-reference",
      isbn: "0140621431",
      research: true,
      order_url: "http://example.com/order-path"
    )

    post :create, document: attributes.merge(
      related_document_ids: [first_policy.id, second_policy.id]
    )

    created_publication = Publication.last
    assert_equal attributes[:title], created_publication.title
    assert_equal attributes[:body], created_publication.body
    assert_equal [first_policy, second_policy], created_publication.related_documents
    assert_equal Date.parse("1805-10-21"), created_publication.publication_date
    assert_equal "unique-reference", created_publication.unique_reference
    assert_equal "0140621431", created_publication.isbn
    assert created_publication.research?
    assert_equal "http://example.com/order-path", created_publication.order_url
  end

  test 'creating should take the writer to the publication page' do
    post :create, document: attributes_for(:publication)

    assert_redirected_to admin_publication_path(Publication.last)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'creating with invalid data should leave the writer in the publication editor' do
    attributes = attributes_for(:publication)
    post :create, document: attributes.merge(title: '')

    assert_equal attributes[:body], assigns(:document).body, "the valid data should not have been lost"
    assert_template "documents/new"
  end

  test 'creating with invalid data should set an alert in the flash' do
    attributes = attributes_for(:publication)
    post :create, document: attributes.merge(title: '')

    assert_equal 'There are some problems with the document', flash.now[:alert]
  end

  test 'updating should save modified document attributes' do
    publication = create(:publication)

    put :update, id: publication, document: publication.attributes.merge(
      title: "new-title",
      body: "new-body",
      publication_date: Date.parse("1815-06-18"),
      unique_reference: "new-reference",
      isbn: "0099532816",
      research: true,
      order_url: "https://example.com/new-order-path"
    )

    saved_publication = publication.reload
    assert_equal "new-title", saved_publication.title
    assert_equal "new-body", saved_publication.body
    assert_equal Date.parse("1815-06-18"), saved_publication.publication_date
    assert_equal "new-reference", saved_publication.unique_reference
    assert_equal "0099532816", saved_publication.isbn
    assert saved_publication.research?
    assert_equal "https://example.com/new-order-path", saved_publication.order_url
  end

  test 'updating should remove all related documents if none in params' do
    policy = create(:policy)
    publication = create(:publication, related_documents: [policy])

    put :update, id: publication, document: {}

    publication.reload
    assert_equal [], publication.related_documents
  end

  test 'updating should take the writer to the publication page' do
    publication = create(:publication)
    put :update, id: publication, document: publication.attributes.merge(
      title: 'new-title',
      body: 'new-body'
    )

    assert_redirected_to admin_publication_path(publication)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'updating with invalid data should not save the publication' do
    attributes = attributes_for(:publication)
    publication = create(:publication, attributes)
    put :update, id: publication, document: attributes.merge(title: '')

    assert_equal attributes[:title], publication.reload.title
    assert_template "documents/edit"
    assert_equal 'There are some problems with the document', flash.now[:alert]
  end

  test 'updating a stale publication should render edit page with conflicting publication' do
    publication = create(:draft_publication)
    lock_version = publication.lock_version
    publication.touch

    put :update, id: publication, document: publication.attributes.merge(lock_version: lock_version)

    assert_template 'edit'
    conflicting_publication = publication.reload
    assert_equal conflicting_publication, assigns[:conflicting_document]
    assert_equal conflicting_publication.lock_version, assigns[:document].lock_version
    assert_equal %{This document has been saved since you opened it}, flash[:alert]
  end

  test "cancelling a new publication takes the user to the list of drafts" do
    get :new
    assert_select "a[href=#{admin_documents_path}]", text: /cancel/i, count: 1
  end

  test 'edit displays publication form' do
    publication = create(:publication)

    get :edit, id: publication

    assert_select "form#document_edit[action='#{admin_publication_path(publication)}']"
  end

  test "cancelling an existing publication takes the user to that publication" do
    draft_publication = create(:draft_publication)
    get :edit, id: draft_publication
    assert_select "a[href=#{admin_publication_path(draft_publication)}]", text: /cancel/i, count: 1
  end

  test 'updating a submitted publication with bad data should show errors' do
    attributes = attributes_for(:submitted_publication)
    submitted_publication = create(:submitted_publication, attributes)
    put :update, id: submitted_publication, document: attributes.merge(title: '')

    assert_template 'edit'
  end

  test "should render the content using govspeak markup" do
    draft_publication = create(:draft_publication, body: "body-in-govspeak")
    Govspeak::Document.stubs(:to_html).with("body-in-govspeak").returns("body-in-html")

    get :show, id: draft_publication

    assert_select ".body", text: "body-in-html"
  end

  test "should display publication attributes" do
    publication = create(:publication,
      publication_date: Date.parse("1916-05-31"),
      unique_reference: "unique-reference",
      isbn: "0099532816",
      research: true,
      order_url: "http://example.com/order-path"
    )

    get :show, id: publication

    assert_select ".document_view" do
      assert_select ".publication_date", text: "May 31st, 1916"
      assert_select ".unique_reference", text: "unique-reference"
      assert_select ".isbn", text: "0099532816"
      assert_select ".research", text: "Yes"
      assert_select "a.order_url[href='http://example.com/order-path']"
    end
  end

  test "should not display an order link if no order url exists" do
    publication = create(:publication, order_url: nil)

    get :show, id: publication

    assert_select ".document_view" do
      refute_select "a.order_url"
    end
  end
end
