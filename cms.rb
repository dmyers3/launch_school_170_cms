require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secretpassword'
end

# Create separate paths for development and testing
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

helpers do
  def signed_in?
    session[:username]
  end
end

before do
  @root = data_path
  @files = Dir.entries(@root).select do |file| 
    file != "." && file != ".."
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

# determines type of file and displays accordingly
def display_file(file_name)
  file_content = File.read(File.join(@root, file_name))
  case File.extname(file_name)
  when ".md"
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    erb markdown.render(file_content)
  when ".txt" 
    headers["Content-Type"] = "text/plain"
    file_content
  end
end

def redirect_signed_out_user
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# index page
get "/" do
  erb(:index)
end

# Sign in form
get "/users/signin" do
  erb :signin
end

# Sign user in
post "/users/signin" do
  credentials = load_user_credentials
  username = params[:username]
  
  
  if credentials.key?(username) && BCrypt::Password.new(credentials[username]) == params[:password]
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials."
    status 422
    erb :signin
  end
end

# Sign user out
post "/users/signout" do
  session[:username] = nil
  session[:password] = nil
  session[:message] = "You have been signed out."
  redirect "/"
end

# new file page
get "/new" do
  redirect_signed_out_user
  erb :new
end

# create new file
post "/" do
  redirect_signed_out_user
  if params[:filename].strip == ""
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    File.write(File.join(@root, params[:filename]),"")
    session[:message] = "#{params[:filename]} has been created."
    redirect "/"
  end
end

# displays specific file
get "/:file_name" do
  
  file_name = params[:file_name]
  if @files.include? file_name
    display_file(file_name)
  else
    session[:message] = "#{file_name} does not exist."
    redirect "/"
  end
end

# edit file page
get "/:file_name/edit" do
  redirect_signed_out_user
  @file_name = params[:file_name]
  @file_content = File.read(File.join(@root, @file_name))
  
  erb :edit
end

# edits file
post "/:file_name" do
  redirect_signed_out_user
  file_name = params[:file_name]
  File.write(File.join(@root, file_name), params[:edited_file])
  
  session[:message] = "#{file_name} has been updated."
  redirect "/"
end

post "/:file_name/destroy" do
  redirect_signed_out_user
  file_name = params[:file_name]
  File.delete(File.join(@root, file_name))
  session[:message] = "#{file_name} was deleted."
  
  redirect "/"
end


# config file stores users/passwords that can log in
# when signing in check to see if user/pw combo is in config file
  # if so user can log in
  # if not, user redirected back to login page
# only admin can edit list
