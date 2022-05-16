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
  'Error 404. This page does not exist!'
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

def redirect_if_loggedin
  redirect '/' if logged_in?
end

def error_valid_credentials(email, pwd)
  user_pw = @storage.get_user_password(email)
  msg = 'Please, enter valid current credentials.'
  msg unless user_pw && (BCrypt::Password.new(user_pw) == pwd)
end

def error_new_info(full_name, user_email, phone, pass1, pass2)
  error_first_last_names(full_name) ||
    error_new_email(user_email) ||
    error_phone(phone) ||
    error_new_pwd(pass1, pass2)
end

def error_new_email(user_email)
  if user_email.empty?
    'You must enter a user email.'
  elsif @storage.find_user_id(user_email)
    'This email already exists. Use another one!'
  end
end

def error_phone(phone)
  msg = 'Error! The phone number must contain only 10 digits.'
  msg if !phone.empty? && (phone.size != 10)
end

def error_first_last_names(full_name)
  if full_name[0].empty?
    'You must enter a valid first name of the user.'
  elsif full_name[0].size > 25
    'Error. Maximum allowed length of the first name is 25 characters.'
  elsif full_name[1].empty?
    'You must enter a valid second name of the user.'
  elsif full_name[1].size > 50
    'Error. Maximum allowed length of the second name is 50 characters.'
  end
end

def error_new_pwd(pwd1, pwd2)
  if pwd1 != pwd2
    'Entered passwords do not match.'
  elsif pwd1.include?(' ')
    'Use of spaces in passwords is not allowed!'
  elsif pwd1.size < 4
    'The password must be 4 or more characters.'
  end
end

def error_new_skill(skill_name)
  if skill_name.empty?
    'You must enter a valid skill name.'
  elsif current_user_info[:skills].include?(skill_name)
    'This skill is already on your list.'
  elsif skill_name.size > 25
    'The skill name must be less than 25 characters.'
  elsif skill_name.count('[A-Za-z0-9-\'\/]') != skill_name.size
    'Error! Allowed characters for skill name are: ' \
     'letters, digits, dash, slash, and apostrophe only.'
  end
end

def login
  u_email = params[:user_email].strip
  session[:login] = @storage.find_user_id(u_email)
  session[:email] = u_email
end

def current_user_info
  @storage.user_profile_info(session[:login])
end

def encrypt_password(pwd_str)
  BCrypt::Password.create(pwd_str).to_s
end

def redirect_if_nonexist_user(user_id)
  return if (user_id !~ /\D/) && @storage.user_exists?(user_id)

  session[:error] = 'This page does not exist.'
  redirect '/'
end

def clean_name(name)
  name.to_s.strip.capitalize
end

############################### MAIN ###########################################

get '/' do
  erb :index, layout: :layout
end

get '/signin' do
  redirect_if_loggedin

  erb :signin, layout: :layout
end

post '/signin' do
  redirect_if_loggedin

  if (error = error_valid_credentials(params[:user_email], params[:password]))
    session[:error] = error
    status 422
    erb :signin, layout: :layout
  else
    login
    session[:success] = 'Welcome!'
    redirect '/'
  end
end

get '/my_profile' do
  redirect_if_logout

  @user_info = current_user_info
  @user_requests = @storage.user_requests(session[:login])
  erb :user_profile, layout: :layout
end

post '/signout' do
  redirect_if_logout

  session.delete(:login)
  session.delete(:email)
  session[:success] = 'You have been signed out.'
  redirect '/'
end

get '/signup' do
  redirect_if_loggedin

  erb :signup
end

post '/signup' do
  redirect_if_loggedin
  f_name = clean_name(params[:first_name])
  s_name = clean_name(params[:second_name])
  user_email = params[:user_email].strip.downcase
  phone = params[:user_phone].strip
  location = params[:user_location].strip
  pass1 = params[:password1]
  pass2 = params[:password2]

  error = error_new_info([f_name, s_name], user_email, phone, pass1, pass2)
  if error
    session[:error] = error
    status 422
    erb :signup
  else
    pwd = encrypt_password(pass1)
    @storage.new_user([f_name, s_name], user_email, phone, location, pwd)
    login
    session[:success] = 'Your accout has been successfully created.'
    redirect '/'
  end
end

post '/out_requests/:request_id/close' do
  redirect_if_logout

  request_id = params[:request_id]
  redirect '/' unless @storage.users_request?(session[:login], request_id)

  @storage.close_request(request_id)
  session[:success] = 'Your request was successfully closed.'
  redirect '/my_profile'
end

get '/closed_requests' do
  redirect_if_logout

  @user_requests = @storage.user_requests(session[:login], closed: true)
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

  new_f_name = clean_name(params[:first_name])
  new_s_name = clean_name(params[:second_name])
  new_phone = params[:phone].to_s

  error = (error_first_last_names([new_f_name, new_s_name]) ||
           error_phone(new_phone))
  if error
    status 422
    session[:error] = error
    erb :user_profile_change, layout: :layout
  else
    @storage.change_first_name(session[:login], new_f_name) if new_f_name != @user_info[:f_name]
    @storage.change_second_name(session[:login], new_s_name) if new_s_name != @user_info[:s_name]
    @storage.change_phone(session[:login], new_phone) if new_phone != @user_info[:phone]
    @storage.change_location(session[:login], params[:location]) if params[:location] != @user_info[:location]
    session[:success] = 'Your personal information was successfully changed!'
    redirect '/my_profile'
  end
end

get '/edit_my_skills' do
  redirect_if_logout

  @skill_list = current_user_info[:skills]
  @all_skills = @storage.all_skills
  @skill_selection = @all_skills - @skill_list
  erb :edit_my_skills, layout: :layout
end

post '/skills/:skill/remove' do
  redirect_if_logout
  redirect '/' unless @storage.users_skill?(session[:login], params[:skill])

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
    @skill_list = current_user_info[:skills]
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

get '/change_password' do
  redirect_if_logout
  erb :user_password_change, layout: :layout
end

post '/change_password' do
  redirect_if_logout

  new_pw1 = params[:password1]
  new_pw2 = params[:password2]

  error = (error_valid_credentials(session[:email], params[:password]) ||
           error_new_pwd(new_pw1, new_pw2))
  if error
    status 422
    session[:error] = error
    erb :user_password_change, layout: :layout
  else
    session[:success] = "You've successfully changed your password!"
    @storage.change_user_password(session[:login], encrypt_password(new_pw1))
    redirect '/change_profile'
  end
end

get '/search_skills' do
  redirect_if_logout

  if params[:query]
    @results = @storage.find_user(params[:query].downcase)
    @results.reject! { |u| u[:id] == session[:login] }
  end
  erb :search_skills, layout: :layout
end

get '/:other_id/request_help' do
  redirect_if_logout
  redirect_if_nonexist_user(params[:other_id])

  @user_info = @storage.user_profile_info(params[:other_id])
  erb :new_request, layout: :layout
end

post '/:other_id/request_help' do
  redirect_if_logout
  redirect_if_nonexist_user(params[:other_id])

  skill = params[:skill].strip
  if skill.empty?
    session[:error] = 'Please, select the skill.'
    status 422

    @user_info = @storage.user_profile_info(params[:other_id])
    erb :new_request, layout: :layout
  else
    @storage.open_request(session[:login], params[:other_id],
                          params[:skill], params[:comment].strip)
    session[:success] = 'Your request was successfully opened.'
    redirect '/my_profile'
  end
end

# this path must be only for authorized users (admins) - reformat is as secret option
# later this will be part of admin capabilities
# post '/delete_user/:email' do
#   email = "#{params[:email]}@gmail.com"
#   @storage.delete_user(email) if params[:admin]
# end
