# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'bcrypt'

require_relative 'db_persistence'

configure do
  enable :sessions
  set :session_secret, 'my_$ecre1'
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'db_persistence.rb'
end

before do
  @storage = DatabasePersistance.new(logger)
end

after do
  @storage.disconnect
end

not_found do
  status 404
  "Error 404. This page does not exist!"
end

helpers do
  def logged_in?
    session.key?(:login)
  end

  def highlight_pattern(str, pattern)
    str.gsub(pattern, %(<strong>#{pattern}</strong>))
  end
end

def redirect_if_logout
  return if logged_in?

  session[:error] = 'You must be signed in to do that.'
  redirect '/'
end

def valid_credentials?(email, pwd)
  user_pw = @storage.get_user_password(email)
  user_pw && (BCrypt::Password.new(user_pw) == pwd)
end

def error_new_credentials(first_name, second_name, user_email, pass1, pass2) # may introduce other restrictions for new user's info!
  if first_name.empty?                              # check for valid name
    'You must enter a valid first name of the user.'
  elsif second_name.empty?                              # check for valid surname
    'You must enter a valid second name of the user.'
  elsif user_email.empty?
    'You must enter a user email.'
  elsif @storage.user_id(user_email)    # check of phone (correct length) and location (max 25 letters) must be implemented too
    'This email already exists. Use another one!'
  elsif error_new_pwd(pass1, pass2)
    error_new_pwd(pass1, pass2)
  end
end

def error_new_pwd(pwd1, pwd2)
  if pwd1 != pwd2
    'Entered passwords do not match.'
  elsif pwd1.size < 4
    'The password must be 4 or more characters.'
  end
end

def login
  u_email = params[:user_email].strip
  session[:login] = @storage.user_id(u_email)
  session[:email] = u_email
end

# ++++
get '/' do
  erb :index, layout: :layout
end

get '/signin' do
  redirect '/' if logged_in?
  erb :signin, layout: :layout
end

post '/signin' do
  if valid_credentials?(params[:user_email], params[:password])
    login
    session[:success] = "Welcome!"
    redirect '/'
  else
    session[:error] = 'Invalid Credentials'
    status 422
    erb :signin, layout: :layout
  end
end


def current_user_info
  @storage.user_profile_info(session[:login])
end

get '/my_profile' do
  redirect_if_logout

  @user_info = current_user_info
  @user_requests = @storage.user_requests(session[:login])
  erb :user_profile, layout: :layout
end


post '/signout' do
  session.delete(:login)
  session.delete(:email)
  session[:success] = 'You have been signed out.'
  redirect '/'
end

get '/signup' do
  redirect '/' if logged_in?
  erb :signup
end

def create_new_user(first_name, second_name, user_email, pass, phone, location)
  psswd = encrypt_password(pass)
  @storage.create_user(first_name, second_name, user_email, psswd, phone, location)
end

def encrypt_password(pwd_str)
  BCrypt::Password.create(pwd_str).to_s
end

post '/signup' do
  redirect '/' if logged_in?
  f_name = params[:first_name].strip.capitalize
  s_name = params[:second_name].strip.capitalize
  user_email = params[:user_email].strip.downcase
  phone = params[:user_phone].strip
  location =  params[:user_location].strip
  pass1 = params[:password1]
  pass2 = params[:password2]

  error = error_new_credentials(f_name, s_name, user_email, pass1, pass2)
  if error
    session[:error] = error
    status 422
    erb :signup
  else
    pwd = encrypt_password(pass1)
    @storage.new_user(f_name, s_name, user_email, phone, location, pwd)
    login
    session[:success] = 'Your accout has been successfully created.'
    redirect '/'
  end
end

post "/out_requests/:request_id/close" do
  redirect_if_logout

  @storage.close_request(params[:request_id])
  session[:success] = "Your request was successfully closed."
  redirect '/my_profile'
end

get '/closed_requests' do
  redirect_if_logout

  @user_requests = @storage.user_requests(session[:login], closed = true)
  erb :closed_requests, layout: :layout
end

get '/change_profile' do
  redirect_if_logout

  @user_info = current_user_info
  erb :user_profile_change, layout: :layout
end

post '/change_profile' do
  redirect_if_logout

  @user_info = current_user_info
  new_f_name = params[:first_name].to_s.downcase.capitalize
  @storage.change_first_name(session[:login], new_f_name) if (!new_f_name.empty? && new_f_name != @user_info[:f_name])
  new_s_name = params[:second_name].to_s.downcase.capitalize
  @storage.change_second_name(session[:login], new_s_name) if (!new_s_name.empty? && new_s_name != @user_info[:s_name])
  new_phone = params[:phone].to_s.gsub(/\D/, '')
  @storage.change_phone(session[:login], new_phone) if new_phone != @user_info[:phone]
  @storage.change_location(session[:login], params[:location]) if params[:location] != @user_info[:location]
  session[:success] = 'Your personal information was successfully changed!'
  redirect '/my_profile'
end

get '/edit_my_skills' do
  redirect_if_logout

  @skill_list = current_user_skills
  @all_skills = @storage.all_skills
  @skill_selection = @all_skills - @skill_list
  erb :edit_my_skills, layout: :layout
end

post '/skills/:skill/remove' do
  redirect_if_logout

  @storage.remove_skill(params[:skill], session[:login])
  session[:success] = 'The skill was successfully removed!'
  redirect '/edit_my_skills'
end

post '/edit_my_skills' do
  redirect_if_logout

  new_skill = (params[:new_skill] ? params[:new_skill].downcase.strip : '')
  error = error_new_skill(new_skill)
  if error
    session[:error] = error
    status 422
    @skill_list = current_user_skills
    @all_skills = @storage.all_skills
    @skill_selection = @all_skills - @skill_list
    erb :edit_my_skills, layout: :layout
  else
    @storage.add_skill(new_skill) unless @storage.all_skills.include?(new_skill)
    @storage.add_user_skill(new_skill, session[:login])
    session[:success] = 'New skill was successfullly added!'
    redirect '/edit_my_skills'
  end

end

def error_new_skill(skill_name)
  if skill_name.empty?
    'You must enter a valid skill name.'
  elsif current_user_skills.include?(skill_name)
    'This skill is already on your list.'
  end
end

def current_user_skills
  skills_arr = current_user_info[:skills]
  skills_arr ? skills_arr.split(', '):[]
  # current_user_info[:skills].split(', ')
end

get '/change_password' do
  redirect_if_logout
  erb :user_password_change, layout: :layout
end

post '/change_password' do
  redirect_if_logout

  new_pw1 = params[:password1]
  new_pw2 = params[:password2]

  if valid_credentials?(session[:email], params[:password])
    error = error_new_pwd(new_pw1, new_pw2)
    if error
      status 422
      session[:error] = error
      erb :user_password_change, layout: :layout
    else
      session[:success] = "You've successfully changed your password!"
      @storage.change_user_password(session[:login], encrypt_password(new_pw1))
      redirect '/change_profile'
    end
  else
    status 422
    session[:error] = 'Please, enter valid current password.'
    erb :user_password_change, layout: :layout
  end
end

get '/search_skills' do
  redirect_if_logout

  if params[:query]
    @results = @storage.find_user(params[:query])
    @results.reject! { |u| u[:id] == session[:login]} unless @results.empty?
  end
  erb :search_skills, layout: :layout
end

get '/:other_id/request_help' do
  redirect_if_logout
  redirect_if_nonexist_user(params[:other_id])

  # check if user id exists. if not - same page as non existing page

  @user_info = @storage.user_profile_info(params[:other_id])
  @user_info[:skills] = @user_info[:skills].split(', ')
  erb :new_request, layout: :layout
end

post '/:other_id/create_new_request' do
  redirect_if_logout
  redirect_if_nonexist_user(params[:other_id])

  @storage.open_request(session[:login], params[:other_id], params[:skill], params[:comment])
  session[:success] = "Your request was successfully opened."

  redirect '/my_profile'
end

def redirect_if_nonexist_user(user_id)
  return if (user_id !~ /\D/) && @storage.user_exists?(user_id)

  session[:error] = 'This page does not exist.'
  redirect '/'
end

# this path must be only for authorized users (admins) - reformat is as secret option
# later this will be part of admin capabilities
# post '/delete_user/:email' do
#   email = "#{params[:email]}@gmail.com"
#   @storage.delete_user(email) if params[:admin]
# end
