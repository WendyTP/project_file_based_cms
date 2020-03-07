
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"


configure do
  enable :sessions
  set :session_secret, "secret"
end


def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)       # convert Markdown text to HTML
end

def load_file_content(file_path)
  file_content = File.read(file_path)

  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    file_content
  when ".md"
    erb render_markdown(file_content), layout: :layout
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def error_for_file_name(filename)
  if filename.empty?
    "A name is required."
  elsif ![".txt", ".md"].include?(File.extname(filename))
    "File name needs to end with .txt or .md"
  end
end

def invalid_credentials?(username, password)
  unless username == "admin" && password == "secret"
    "Invalid Credentials"
  end
end

def signed_in?
  session.has_key?(:username)
end

def require_signed_in_user
  unless signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end
  

# view a list of all exisiting documents
get "/" do
  pattern = File.join(data_path, "*")
  @files =  Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :files, layout: :layout
end

# view a single document
get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Render an edit form for an existing document
get "/:filename/edit" do
  require_signed_in_user
  file_path = File.join(data_path, params[:filename])
  @file_content = File.read(file_path)
  @filename = params[:filename]

  erb :edit_file , layout: :layout
end

# update an existing document
post "/:filename" do
  require_signed_in_user
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  updated_content = params[:document_content]

  IO.write(file_path, updated_content)

  session[:success] = "#{filename} has been updated."
  redirect "/"
end

# Render the new document form
get "/files/new" do
  require_signed_in_user
  erb :new_file, layout: :layout
end

# Create a new document
post "/files/create" do
  require_signed_in_user
  filename = params[:new_filename].strip

  error = error_for_file_name(filename)
  if error
    session[:error] = error
    status 422
    erb :new_file, layout: :layout

  else
    file_path = File.join(data_path, filename)
    File.open(file_path, "w")

    session[:success] = "#{filename} was created."
    redirect "/"
  end
end

# Delete an exisiting document
post "/:filename/delete" do
  require_signed_in_user
  filename = params[:filename]
  File.delete(File.join(data_path, filename))
  session[:success] = "#{filename} was deleted."
  redirect "/"
end

# Render the sign in form
get "/users/signin" do
  erb :signin, layout: :layout
end

# Submit the sign in form
post "/users/signin" do
  username = params[:username]
  password = params[:password]

  error = invalid_credentials?(username, password)
  if error
    session[:error] = error
    status 422
    erb :signin, layout: :layout
  else
    session[:username] = username
    session[:success] = "Welcome!"
    redirect "/"
  end
end

# Sign out 
post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end



