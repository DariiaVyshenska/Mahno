CREATE TABLE users(
  id serial PRIMARY KEY,
  first_name text NOT NULL,
  second_name text NOT NULL,
  email text NOT NULL UNIQUE,
  phone text,
  location text,
  password text NOT NULL
);

CREATE TABLE skills(
  id serial PRIMARY KEY,
  skill_name varchar(25) UNIQUE
);

CREATE TABLE skills_users(
  id serial PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  skill_id INT NOT NULL REFERENCES skills(id),
  UNIQUE(user_id, skill_id)
);

CREATE TABLE requests(
  id serial PRIMARY KEY,
  sender_id INT NOT NULL REFERENCES users(id),
  receiver_id INT NOT NULL REFERENCES users(id),
  skill_id INT NOT NULL REFERENCES skills(id),
  open_date date NOT NULL DEFAULT NOW(),
  close_date date,
  completed boolean NOT NULL DEFAULT false,
  result INT,
  request_info text
);

INSERT INTO users (first_name, second_name, email, password)
VALUES
('Dariia', 'Vyshenska', 'vysh@gmail.com', '$2a$12$DYB1eOXYZN0pP5kkJMURneT7lxWTB7t5PVkcDGpy52ZFMlkETUecy'),
('Oleksii', 'Motorykin', 'mot@gmail.com', '$2a$12$QSmMJGaEpDTh5PbdFB/98OT5E.Cmo1o.RA0eQouauJCMKLgRe00wC');

INSERT INTO skills(skill_name)
VALUES
('sql'),
('ruby'),
('lsms'),
('python'),
('science');

INSERT INTO skills_users (user_id, skill_id)
VALUES
(1, 1),
(1, 2),
(2, 3),
(1, 4),
(2, 4),
(1, 5),
(2, 5);

INSERT INTO requests (sender_id, receiver_id, skill_id, request_info)
VALUES
(1, 2, 3, 'analysis of the data'),
(2, 1, 2, 'debugging'),
(2, 1, 4, 'help with package'),
(1, 2, 5, 'consultation'),
(1, 2, 4, 'debugging');

UPDATE requests
SET completed = true,
    result = 3
WHERE id = 4;

UPDATE requests
SET completed = true,
    result = 2
WHERE id = 5;
