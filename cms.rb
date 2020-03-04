
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
  markdown.render(text)
end

def load_file_content(file)
  file_content = File.read(file)

  case File.extname(file)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    file_content
  when ".md"
    render_markdown(file_content)
  end
end

 
root = File.expand_path("..", __FILE__)

get "/" do
  @files =  Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :index, layout: :layout
end

get "/:filename" do
  file_path = "#{root}" + "/data/#{params[:filename]}"

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end