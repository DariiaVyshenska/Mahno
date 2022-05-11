ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../mahno"

class MahnoTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def user_session
    { "rack.session" => { login: "1", email: 'vysh@gmail.com'} }
  end

  def setup
    system('createdb mahno_test')
    system('psql -d mahno_test < schema.sql')
  end

  def teardown
    system('dropdb mahno_test')
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<a href="/signin">Sign In)

    get '/', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com)
    assert_includes last_response.body, %q(<a href="/my_profile">Go to my profile<)
  end

  def test_user_profile
    get '/my_profile'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/my_profile', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com)
    assert_includes last_response.body, %q(<p><b>Name:</b> Dariia Vyshenska</p>)
    refute_includes last_response.body, %q(<p><a href="/user_profile">Go to my profile)
  end

  def test_closed_requests
    get '/closed_requests'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/closed_requests', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    refute_includes last_response.body, %q(Signed in with email: vysh@gmail.com)
    assert_includes last_response.body, %q(<h2>My closed requests.</h2>)
  end

  def test_signin_page
    get '/signin'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<input type='email' name='user_email' id='user_email' value=)
    assert_includes last_response.body, %q(<input type='password' name='password' id='password' >)

    get '/signin', {}, user_session
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, %q(This is <b>Mahno App</b>)
  end

  def test_invalid_signin
    post '/signin', user_email: '  ', password: '1234'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', user_email: 'vysh@gmail.com', password: 'mmm'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', user_email: 'wrong@gmail.com', password: '1234'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', user_email: 'wrong@gmail.com', password: 'wrong_pass'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]
  end

  def test_valid_signin
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'
    assert_equal 302, last_response.status
    assert_equal '1', session[:login]
    assert_equal 'vysh@gmail.com', session[:email]
    assert_equal 'Welcome!', session[:success]

    get '/'
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com.)
  end

  def test_signout
    get '/', {}, { "rack.session" => {login: '1', email: 'vysh@gmail.com'}}
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com.)

    post '/signout'
    assert_equal 302, last_response.status
    assert_nil session[:login]
    assert_nil session[:email]
    assert_equal 'You have been signed out.', session[:success]

    get last_response["Location"]
    assert_includes last_response.body, 'Sign In'
  end

  def test_signup_page
    get '/signup'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<label for="user_email">User's email:</label>)
    assert_includes last_response.body, 'Repeat Password:'
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit">Sign up)

    get '/signup', {}, user_session
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com.)
  end

  def test_signup_new_user
    # signing up with test user
    post '/signup', first_name: 'test_name', second_name: 'test_surname', user_email: 'test@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'test@gmail.com', session[:email]
    assert_equal 'Your accout has been successfully created.', session[:success]

    get last_response["Location"]
    assert_includes last_response.body, %q(Signed in with email: test@gmail.com.)
    assert_includes last_response.body, %q(<button type="submit">Sign Out)
  end

  def test_signup_with_wrong_credentials
    post '/signup', first_name: '', second_name: 'test_surname', user_email: 'test@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a valid first name of the user.'

    post '/signup', first_name: 'test_name', second_name: '', user_email: 'test@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a valid second name of the user.'

    post '/signup', first_name: 'test_name', second_name: 'test_surname', user_email: '', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a user email.'

    post '/signup', first_name: 'test_name', second_name: 'test_surname', user_email: 'vysh@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'This email already exists. Use another one!'

    post '/signup', first_name: 'test_name', second_name: 'test_surname', user_email: 'test@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: 'secret',  password2: 'secret1'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Entered passwords do not match.'

    post '/signup', first_name: 'test_name', second_name: 'test_surname', user_email: 'test@gmail.com', user_phone: '5411111111', user_location: 'office #2', password1: '123',  password2: '123'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The password must be 4 or more characters.'
  end

  def test_change_profile
    get '/change_profile'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/change_profile', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<p><a href="/my_profile">Go to my profile</a><p>)
    assert_includes last_response.body, %q(<input id="new_file_text" type="submit" value="Save Changes">)
  end

  def test_change_profile_name
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'

    post '/change_profile', first_name: 'Odarka'
    assert_equal 302, last_response.status
    assert_equal 'Your personal information was successfully changed!', session[:success]

    get last_response["Location"]
    assert_includes last_response.body, %q(<p><b>Name:</b> Odarka)

    # changing the name back
    post '/change_profile', first_name: 'Dariia'
  end

  def test_edit_skills_page
    get '/edit_my_skills'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/edit_my_skills', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Manage my skills.)
  end

  def test_edit_skills
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'

    post '/edit_my_skills', new_skill: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a valid skill name.'

    post '/edit_my_skills', new_skill: 'sql'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'This skill is already on your list.'

    post '/edit_my_skills', new_skill: 'test_skill'
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, '<form action="/skills/test_skill/remove" method="post">'

    post '/skills/test_skill/remove'
    assert_equal 302, last_response.status
    assert_equal 'The skill was successfully removed!', session[:success]

    get last_response["Location"]
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Manage my skills.)
    refute_includes last_response.body, %q(<form action="/skills/test_skill/remove" method="post">)
  end

  def test_change_pass_page
    get '/change_password'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]


    get '/change_password', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<h2>Change password.</h2>)
    assert_includes last_response.body, %q(<input type="password" name="password" id="password")
  end

  def test_change_password
    post '/change_password'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # login
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'
    # change password - wrong current password
    post '/change_password', password: '1234abcd', password1: '123456', password2: '123456'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid current password.'
    # change pwd - not equal pswds
    post '/change_password', password: '1234', password1: '123456', password2: '1234567'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Entered passwords do not match.'
    # change pwd - too short pswds
    post '/change_password', password: '1234', password1: '1', password2: '1'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The password must be 4 or more characters.'

    # change password succesfully
    post '/change_password', password: '1234', password1: '12345', password2: '12345'
    assert_equal 302, last_response.status
    assert_equal "You've successfully changed your password!", session[:success]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<p><a href="/my_profile">Go to my profile</a><p>)
    assert_includes last_response.body, %q(<input id="new_file_text" type="submit" value="Save Changes">)

    # logout
    post '/signout'
    assert_equal 302, last_response.status
    assert_nil session[:login]
    assert_nil session[:email]
    assert_equal 'You have been signed out.', session[:success]

    # login with new Credentials
    post '/signin', user_email: 'vysh@gmail.com', password: '12345'
    assert_equal 302, last_response.status
    assert_equal '1', session[:login]
    assert_equal 'vysh@gmail.com', session[:email]
    assert_equal 'Welcome!', session[:success]
    # change password back
    post '/change_password', password: '12345', password1: '1234', password2: '1234'
  end

  def test_search_request_skill_page
    # redir when logged out
    get '/search_skills'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # access the page when logged in
    get '/search_skills', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(<h2>Open new request</h2>)
    assert_includes last_response.body, %q(<label for="query">Enter the skill of interest:</label>)

    # search unexisting skill
    get '/search_skills', {query: 'timothy'}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Sorry, no matches were found.)

    # search exisiting skill
    get '/search_skills', {query: 's'}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Oleksii Motorykin:  l<strong>s</strong>m<strong>s</strong>, <strong>s</strong>cience)
    assert_includes last_response.body, %q(form action="/2/request_help)
  end

  def test_open_and_close_new_request_page
    # access both pages when logged out
    get '/2/request_help'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/2/create_new_request'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # assecss
    get '/2/request_help', {}, user_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Oleksii Motorykin)
    assert_includes last_response.body, %q(<form action="/2/create_new_request" method="POST">)

    # # assess
    post '/2/create_new_request', {skill: 'science', comment: 'test'}, user_session
    assert_equal 302, last_response.status
    assert_equal 'Your request was successfully opened.', session[:success]

    get last_response["Location"]
    assert_includes last_response.body, %q(<b>Skill:</b> science; <b>Requested from:</b> Oleksii Motorykin)
    assert_includes last_response.body, %q(<form action="/out_requests/6/close" method="post")

    # now close this request
    post '/out_requests/6/close', {}, user_session
    assert_equal 302, last_response.status
    assert_equal 'Your request was successfully closed.', session[:success]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, %q(Signed in with email: vysh@gmail.com)
    assert_includes last_response.body, %q(<p><b>Name:</b> Dariia Vyshenska</p>)
    refute_includes last_response.body, %q(<b>Skill:</b> science; <b>Requested from:</b> Oleksii Motorykin)
    refute_includes last_response.body, %q(<form action="/out_requests/6/close" method="post")
  end

  def test_page_not_found
    get '/i_do_not_exist'
    assert_equal 404, last_response.status
    assert_includes last_response.body, %q(Error 404. This page does not exist!)
  end

  def test_access_non_existant_user_page
    # not logged in
    post '/102/create_new_request'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]
    get '/102/request_help'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    #logged in
    post '/102/create_new_request', {}, user_session
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist.', session[:error]

    get '/102/request_help' , {}, user_session
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist.', session[:error]
  end
end
