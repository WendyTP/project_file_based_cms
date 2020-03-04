ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
    assert_includes(last_response.body, "history.txt")
  end

  def test_file
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
    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>Ruby is...</h1>" )
  end

  def test_editing_document
    get "/changes.txt/edit"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_post_updated_document
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


  
end