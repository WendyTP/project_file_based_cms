
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"


configure do
  enable :sessions
  set :session_secret, "secret"
end

# convert Markdown text to HTML
def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def current_files_list
  pattern = File.join(data_path, "*")
  @files =  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
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

def error_for_file_name(filename)
  if filename.empty?
    "A name is required."
  elsif ![".txt", ".md"].include?(File.extname(filename))
    "File name needs to end with .txt or .md"
  end
end

def filename_exist?(filename)
  current_files_list.include?(filename)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_credentials_path
  if ENV["RACK_ENV"] == "test"
    file_path = File.expand_path("../test/users.yml", __FILE__)
  else
    file_path = File.expand_path("../users.yml", __FILE__)
  end
end

def load_user_credentials
  file_path = user_credentials_path
  YAML.load_file(file_path)
end

def store_user_credentials(username, password)
  user_credentials = load_user_credentials
  user_credentials[username] = password
  File.write(user_credentials_path, user_credentials.to_yaml)
end

def correct_password?(password, encrypted_password)
  BCrypt::Password.new(encrypted_password) == password
end

def invalid_credentials?(username, password)
  user_credentials = load_user_credentials
  encrypted_password = user_credentials[username]
  unless user_credentials.has_key?(username) && correct_password?(password, encrypted_password)
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

def invalid_username(username)
  user_credentials = load_user_credentials
  if username.size == 0
    "Username can not be empty."
  elsif user_credentials.has_key?(username)
    "Username already exists."
  end
end

def invalid_password(password, reconfirmed_password)
  unless password.match?(/\A\w{5,20}\z/) && password == reconfirmed_password
    "password is invalid."
  end
end
  

# view a list of all exisiting documents
get "/" do
  @files = current_files_list
  
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

#<form action="/<%= @filename %>/edit" method="post">
# update an existing document content
post "/:filename/edit" do
  require_signed_in_user
  filename = params[:filename]
 
    file_path = File.join(data_path, filename)
    updated_content = params[:document_content]

    IO.write(file_path, updated_content)

    session[:success] = "#{filename} has been updated."
    redirect "/"
end

# render edit-filename form
get "/:filename/edit_filename" do
  require_signed_in_user
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]

  erb :edit_filename , layout: :layout
end

# update exisitng filename
post "/:filename/edit_filename" do
  require_signed_in_user
  current_file_path = File.join(data_path, params[:filename])
  file_content = File.read(current_file_path)
  @filename = params[:filename]

  new_filename = params[:new_filename].strip

  error = error_for_file_name(new_filename)
  if error
    session[:error] = error
    status 422
    erb :edit_filename, layout: :layout
  elsif filename_exist?(new_filename)
    session[:error] = "#{new_filename} already exisits."
    status 422
    erb :edit_filename, layout: :layout
  else
    new_file_path = File.join(data_path, new_filename)
    File.rename(current_file_path, new_file_path)
    session[:success] = "Filename is updated"
    redirect "/"
  end
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
  elsif filename_exist?(filename)
    session[:error] = "#{filename} already exisits."
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

# Render sign up form
get "/users/signup" do
  erb :signup, layout: :layout
end

# Submit sign up form
post "/users/signup" do
  username = params[:username].strip
  password = params[:password].strip
  reconfirmed_password = params[:reconfirmed_password].strip

  username_error = invalid_username(username)
  password_error = invalid_password(password, reconfirmed_password)
  if username_error
    session[:error] = username_error
    status 422
    erb :signup, layout: :layout
  elsif password_error
    session[:error] = password_error
    status 422
    erb :signup, layout: :layout
  else
    encrypted_password = BCrypt::Password.create(password).to_s
    store_user_credentials(username, encrypted_password)

    session[:username] = username
    session[:success] = "Sign up succeeded! Welcome!"
    redirect "/"
  end
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

# duplicate existing document
post "/:filename/duplicate" do
  require_signed_in_user
  file_path = File.join(data_path,params[:filename]) # ../data/changes.txt
  @content = File.read(file_path)

  file_directory = File.dirname(file_path)   # ../data
  filename_no_extention = File.basename(file_path, ".*") # "changes"
  file_extention = File.extname(file_path)     # ".txt"
  
  new_file_path = File.join(file_directory, "#{filename_no_extention}_copy#{file_extention}") # "../data/changes_copy.txt"
  
  IO.write(new_file_path, @content)
  session[:success] = "Duplication succeeded! You can change the name of the file."
  redirect "/#{File.basename(new_file_path)}/edit_filename"   # "/changes_copy.txt/edit"
end
