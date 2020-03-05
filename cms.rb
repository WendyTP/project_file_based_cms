
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
  file_path = File.join(data_path, params[:filename])
  @file_content = File.read(file_path)
  @file_name = params[:filename]

  erb :edit_file , layout: :layout
end

# update an existing document
post "/:filename" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  updated_content = params[:document_content]

  IO.write(file_path, updated_content)

  session[:success] = "#{file_name} has been updated."
  redirect "/"
end

# Render the new document form
get "/files/new" do
  
  erb :new_file, layout: :layout
end

def error_for_file_name(file_name)
  if file_name.empty?
    "A name is required."
  elsif ![".txt", ".md"].include?(File.extname(file_name))
    "File name needs to end with .txt or .md"
  end
end
# Create a new document
post "/files/create" do
  file_name = params[:new_file_name].strip

  error = error_for_file_name(file_name)
  if error
    session[:error] = error
    status 422
    erb :new_file, layout: :layout

  else
    file_path = File.join(data_path, file_name)
    File.open(file_path, "w")

    session[:success] = "#{file_name} was created."
    redirect "/"
  end

end
