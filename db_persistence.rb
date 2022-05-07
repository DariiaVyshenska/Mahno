# frozen_string_literal: true

require 'pg'

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'mahno')
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def get_user_password(user_email)
    sql = "SELECT password FROM users WHERE email = $1"
    result = query(sql, user_email)
    result.values.size.zero? ? nil:result.values.first.first
  end

  def user_id(user_email)
    sql = "SELECT id FROM users WHERE email = $1"
    result = query(sql, user_email)
    result.values.size.zero? ? nil:result.values.first.first
  end

  def new_user(f_name, s_name, user_email, phone, location, pwd)
    sql = <<~SQL
    INSERT INTO users (first_name, second_name, email, phone, location, password)
    VALUES ($1, $2, $3, $4, $5, $6)
    SQL
    query(sql, f_name, s_name, user_email, phone, location, pwd)
  end

  def user_profile_info(id)
    sql = <<~SQL
    SELECT users.first_name, users.second_name,
            users.email, users.phone, users.location, string_agg(skills.skill_name, ', ') AS skills
    FROM users LEFT JOIN skills_users ON users.id = skills_users.user_id LEFT JOIN skills ON skills_users.skill_id = skills.id
    WHERE users.id = $1
    GROUP BY users.id;
    SQL
    result = query(sql, id)

    result.map do |tuple|
      {
        f_name: tuple["first_name"],
        s_name: tuple["second_name"],
        email: tuple["email"],
        phone: tuple["phone"],
        location: tuple["location"],
        skills: tuple["skills"]
      }
    end.first
  end

  def user_requests(id, closed = false)
    status = (closed ? 'true':false)
    { outbaund: out_requests(id, status),
      inbaund: in_requests(id, status) }
  end

  def close_request(request_id)
    sql = <<~REQUEST
    UPDATE requests
      SET close_date = NOW(),
          completed = true
          WHERE id = $1
    REQUEST
    query(sql, request_id)
  end

  def change_first_name(id, new_f_name)
    sql = <<~REQUEST
    UPDATE users
      SET first_name = $1
      WHERE id = $2
    REQUEST
    query(sql, new_f_name, id)
  end

  def change_second_name(id, new_s_name)
    sql = <<~REQUEST
    UPDATE users
      SET second_name = $1
      WHERE id = $2
    REQUEST
    query(sql, new_s_name, id)
  end

  def change_phone(id, new_phone)
    sql = <<~REQUEST
    UPDATE users
      SET phone = $1
      WHERE id = $2
    REQUEST
    query(sql, new_phone, id)
  end

  def change_location(id, new_location)
    sql = <<~REQUEST
    UPDATE users
      SET location = $1
      WHERE id = $2
    REQUEST
    query(sql, new_location, id)
  end

  def remove_skill(skill_name, user_id)
    sql = <<~REQUEST
    DELETE FROM skills_users
    WHERE skills_users.id IN (
      SELECT skills_users.id
        FROM skills_users
        JOIN skills ON skills_users.skill_id = skills.id
      WHERE skills_users.user_id = $1 AND skills.skill_name = $2)
    REQUEST
    query(sql, user_id, skill_name)
  end

  def all_skills
    sql = <<~REQUEST
    SELECT skill_name FROM skills
    REQUEST
    query(sql).values.flatten
  end

  def add_skill(new_skill_name)
    sql = <<~REQUEST
    INSERT INTO skills (skill_name) VALUES ($1)
    REQUEST
    query(sql, new_skill_name)
  end

  def add_user_skill(skill_name, user_id)
    sql = <<~REQUEST
    INSERT INTO skills_users (user_id, skill_id) VALUES ($1, (SELECT id FROM skills WHERE skill_name = $2))
    REQUEST
    query(sql, user_id, skill_name)
  end

  def change_user_password(user_id, user_new_pwd)
    sql = <<~REQUEST
    UPDATE users
      SET password = $1
      WHERE id = $2
    REQUEST
    query(sql, user_new_pwd, user_id)
  end

  ### tmp method, delete or repurpuse later!
  def delete_user(email)
    sql = "DELETE FROM users WHERE email = $1"
    query(sql, email)
  end
  ###

  private

  def out_requests(user_id, status)
    sql = <<~REQUEST
    SELECT requests.id,
      users.first_name,
      users.second_name,
      requests.open_date,
      requests.close_date,
      skills.skill_name
    FROM requests
    JOIN users ON requests.receiver_id = users.id
    JOIN skills ON requests.skill_id = skills.id
    WHERE sender_id = $1 AND completed IS #{status}
    REQUEST

    result = query(sql, user_id)

    result.map do |tuple|
      {
        request_id: tuple["id"],
        skill: tuple["skill_name"],
        rec_f_name: tuple["first_name"],
        rec_s_name: tuple["second_name"],
        open_date: tuple["open_date"],
        close_date: tuple["close_date"]
      }
    end
  end

  def in_requests(user_id, status)
    sql = <<~REQUEST
    SELECT requests.id,
      users.first_name,
      users.second_name,
      requests.open_date,
      requests.close_date,
      skills.skill_name
    FROM requests
    JOIN users ON requests.receiver_id = users.id
    JOIN skills ON requests.skill_id = skills.id
    WHERE receiver_id = $1 AND completed IS #{status}
    REQUEST

    result = query(sql, user_id)

    result.map do |tuple|
      {
        request_id: tuple["id"],
        skill: tuple["skill_name"],
        req_f_name: tuple["first_name"],
        req_s_name: tuple["second_name"],
        open_date: tuple["open_date"],
        close_date: tuple["close_date"]
      }
    end
  end
end