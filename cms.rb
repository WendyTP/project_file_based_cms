require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "secret"
end

root = File.expand_path("..", __FILE__)



get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :index, layout: :layout
end

get "/:filename" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  if @files.include?(params[:filename])
    headers["Content-Type"] = "text/plain"

    file_path = "#{root}" + "/data/#{params[:filename]}"
    File.read(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end

end