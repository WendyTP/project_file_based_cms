ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name),"w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document("about.md")
    create_document("changes.txt")

    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
  end

  def test_view_new_file_form
    get "/files/new"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Add a new file:")
    assert_includes(last_response.body, %q(<button type="submit"))
    assert_includes(last_response.body, "Create")
  end

  def test_post_new_file
    post"/files/create",  new_filename: "test.txt"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "test.txt was created.")

    get "/"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "test.txt")
    refute_includes(last_response.body, "test.txt was created.")
  end

  def test_post_new_file_with_empty_name
    post "/files/create", new_filename: ""
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "A name is required.")
    assert_includes(last_response.body, "Add a new file:")
  end

  def test_post_new_file_with_no_file_extention
     post "/files/create", new_filename: "something"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "File name needs to end with .txt or .md")
    assert_includes(last_response.body, "Add a new file:")
  end

  def test_viewing_single_document
    create_document("history.txt", "Ruby 1.0 released.")

    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "Ruby 1.0 released.")
  end

  def test_document_not_found
    get "/notafile.txt"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "notafile.txt does not exist.")

    get "/"
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "notafile.txt does not exist.")
  end

  def test_markdown_render_to_html
    create_document("about.md", "#Ruby is...")

    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>Ruby is...</h1>" )
  end

  def test_editing_document
    create_document("changes.txt")

    get "/changes.txt/edit"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_post_updated_document
    create_document("changes.txt", "This is old content.")

    post "/changes.txt", document_content: "new content"
    assert_equal(302, last_response.status)
    
    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "changes.txt has been updated.")

    get "/"
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "changes.txt has been updated.")

    get "/changes.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content")
  end

  def test_delete_existing_document
    create_document("testing.txt")

    post "/testing.txt/delete"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "testing.txt was deleted.")

    get "/"
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "testing.txt")
  end

  def test_render_signin_form
    get "/users/signin"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Username:")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_submit_success_signin_form
    post "/users/signin",  username: "admin", password: "secret"
    assert_equal(302, last_response.status)
  
    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Welcome!")
    #assert_includes(last_response.body, "Signed in as admin.")
    #assert_includes(last_response.body, %q(<button type="submit">Sign Out))
    
    get "/"
    refute_includes(last_response.body, "Welcome!")
  end

  def test_submit_invalid_credentials
    post "/users/signin",  username: "something", password: "else"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Invalid Credentials")
  end

  def test_user_signout
    post "/users/signin",  username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes(last_response.body, "Welcome!")

    post "/users/signout"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "You have been signed out.")
    assert_includes(last_response.body, "Sign in")
  end
end


