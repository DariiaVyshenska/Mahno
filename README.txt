Hello!
This is a small Sinatra application that allows keeping track of collaborations within a team. This is a work in progress with minimum features.

What you can do using this app:
- Register a new account
- Log in and log out. All core features can be accessed only while signed in.
- Change your personal user information (email and/or password, location, phone, skills)
- Search for people with specific skill.
- Open or close requests for help based on specific skills.

Information on how to start this application
- To run this application (in a development mode), you must have PostgreSQL, Ruby, and Bundler installed on your computer.
- Run `bundler install` to install any gems specified in Gemfile (the archive contains Gemfile.lock, you’ll need to delete it before running bundle).
- After gems have been successfully installed, you should be ok to run the application using `ruby mahno.rb` command. The application was designed to create Postgresql database (if missing) and upload seed data. You then should be able to access the functionality by typing ‘http://localhost:4567/’ in your browser's address bar.
- You can create your account or use an existing account with some seed data. To use the existing account, use the following credentials: username - vysh@gmail.com, password - 1234

The browser (including version number) that I used to test this application - Brave Web Browser (Version 1.41.96 Chromium: 103.0.5060.114 (Official Build) (64-bit))
The version of PostgreSQL I used to create the database - psql (PostgreSQL) 12.11 (Ubuntu 12.11-0ubuntu0.20.04.1)

Any additional details:
- The repo includes test cases for your convenience.
