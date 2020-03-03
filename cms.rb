require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

root = File.expand_path("..", __FILE__)


get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :index, layout: :layout
end

get "/:filename" do
  headers["Content-Type"] = "text/plain"

  file_path = "#{root}" + "/data/#{params[:filename]}"
  @content = File.read(file_path)

  #erb :file, layout: :layout
end