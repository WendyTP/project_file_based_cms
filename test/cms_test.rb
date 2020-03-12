ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"
require "yaml"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  # This method is required for using methods of Rack::Test::Methods
  # return an instance of a Rack app when called. 
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

  # to retrieve data stored in session
  def session
    last_request.env["rack.session"]
  end

  # to add username "admin" to session
  def admin_session
    {"rack.session" => {username: "admin"}}
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
    assert_equal("notafile.txt does not exist.", session[:error])

    get last_response["Location"]

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

    get "/changes.txt/edit", {}, admin_session
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_editing_document_signed_out
    create_document("changes.txt")

    get "/changes.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
  end

  def test_post_updated_document
    create_document("math.txt", "This is old content.")

    post "/math.txt/edit", {document_content: "new content"}, admin_session
    #assert_equal(302, last_response.status)
    assert_equal("math.txt has been updated.", session[:success])

    get "/math.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content")
  end

  def test_post_updated_document_signed_out
    create_document("testing.txt", "This is old content.")

    post "/testing.txt/edit", {document_content: "new content"}
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
  end

  def test_delete_existing_document
    create_document("testing.txt")

    post "/testing.txt/delete", {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("testing.txt was deleted.", session[:success])

    get "/"
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, %q(href="/testing.txt"))
  end

  def test_delete_existing_document_signed_out
    create_document("testing.txt")

    post "/testing.txt/delete"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
  end

   def test_view_new_file_form
    get "/files/new", {}, admin_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Add a new file:")
    assert_includes(last_response.body, %q(<button type="submit"))
    assert_includes(last_response.body, "Create")
  end

  def test_view_new_file_form_signed_out
    get "/files/new"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
  end

  def test_post_new_file
    post"/files/create", {new_filename: "test.txt"}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("test.txt was created.", session[:success])

    get "/"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "test.txt")
  end

  def test_post_new_file_signed_out
    post"/files/create", {new_filename: "test.txt"}
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
  end

  def test_post_new_file_with_empty_name
    post "/files/create", {new_filename: ""}, admin_session
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "A name is required")
    assert_includes(last_response.body, "Add a new file:")
  end

  def test_post_new_file_with_no_file_extention
    post "/files/create", {new_filename: "something"}, admin_session
   assert_equal(422, last_response.status)
   assert_includes(last_response.body, "File name needs to end with .txt or .md")
   assert_includes(last_response.body, "Add a new file:")
 end

 def test_post_new_file_with_duplicated_filename
  create_document("changes.txt")
  post"/files/create", {new_filename: "changes.txt"}, admin_session
  assert_equal(422, last_response.status)
  assert_includes(last_response.body, "changes.txt already exisits.")
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
    assert_equal("Welcome!", session[:success])
    assert_equal("admin", session[:username])
  
    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Signed in as admin.")
    assert_includes(last_response.body, %q(<button type="submit"))
    
    get "/"
    refute_includes(last_response.body, "Welcome!")
  end

  def test_submit_invalid_credentials
    post "/users/signin",  username: "something", password: "else"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Invalid Credentials")
    assert_nil(session[:username])
  end

  def test_user_signout
    get "/", {}, {"rack.session" => {username: "admin"}}
    assert_includes(last_response.body, "Signed in as admin.")

    post "/users/signout"
    assert_equal(302, last_response.status)
    assert_equal("You have been signed out.", session[:success])

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Sign in")
    assert_nil(session[:username])
  end
  
  def test_duplicating_document
    create_document("changes.txt", "new content")

    post "/changes.txt/duplicate", {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("Duplication succeeded! You can change the name of the file.", session[:success])

    get last_response["Location"]
    assert_includes(last_response.body, "changes_copy.txt")
  end

  def test_update_filename
    create_document("changes.txt")

    post "/changes.txt/edit_filename", {new_filename: "testing.txt"}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("Filename is updated", session[:success])

    get last_response["Location"]
    assert_includes(last_response.body, "testing.txt")
  end

  def test_update_filename_with_empty_name
    create_document("changes.txt")

    post "/changes.txt/edit_filename", {new_filename: ""}, admin_session
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "A name is required" )
  end

  def test_render_signup_form
    get "/users/signup"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Re-confirm Password:")
  end

  def test_submit_signup_form
    post "/users/signup",  username: "sunny", password: "rainbow", reconfirmed_password: "rainbow"
    assert_equal(302, last_response.status)
    assert_equal("Sign up succeeded! Welcome!", session[:success])

    get last_response["Location"]
    assert_includes(last_response.body, "Signed in as sunny.")
  end

  def test_empty_username_for_signup
    post "/users/signup",  username: "", password: "chef", reconfirmed_password: "chef"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Username can not be empty.")
  end

  def test_invalid_password_for_signup
    post "/users/signup", username: "john", password: "123er", reconfirmed_password: "123456"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "password is invalid.")
  end
  
end


